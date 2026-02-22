require 'ipaddr'
require 'set'

# Blocks requests from known AI crawler/scraper IP ranges,
# and auto-bans IPs that probe honeypot paths (scanners, exploit kits).
#
# Auto-bans are persisted to storage/banned_ips.txt (a mounted Docker volume)
# and reloaded on startup, so they survive deploys and reboots.
# To permanently block an IP range, add it to BLOCKED_CIDRS and redeploy.
class IpBlocker
  # Static CIDR blocklist — for ranges that should be blocked regardless of
  # the storage volume (e.g. before it's mounted). Add per-IP or CIDR blocks
  # to storage/manual_bans.txt instead — no redeploy needed.
  BLOCKED_CIDRS = [].freeze

  # Requests to these paths immediately ban the IP — no legitimate user hits them.
  HONEYPOT_PATHS = %w[
    /wp-admin /wp-login /wp-config /wp-content /wp-includes /wordpress
    /xmlrpc.php /wlwmanifest.xml
    /.env /.env. /.git/ /.svn/ /.htaccess /.htpasswd
    /phpmyadmin /pma /myadmin /mysql /adminer
    /admin.php /setup.php /install.php /config.php /shell.php /cmd.php
    /etc/passwd /proc/self
    /actuator /solr/ /jmx-console /manager/html /console/
    /cgi-bin/ /fckeditor /ckfinder
  ].freeze

  BAN_TTL = 30 * 24 * 3600  # 30 days in seconds

  AUTO_BANNED = {}           # ip_str => banned_at (Time), with TTL
  AUTO_BANNED_MUTEX = Mutex.new
  MANUAL_BANNED = []         # IPAddr objects loaded from manual_bans.txt (read-only)

  def self.ban_file
    Rails.root.join("storage", "banned_ips.txt")
  end

  def self.manual_ban_file
    Rails.root.join("config", "manual_bans.txt")
  end

  # Called once at boot from an initializer — loads persisted bans.
  # Also reads manual_bans.txt (one IP or CIDR per line, comments with #).
  def self.load_bans!
    cutoff = Time.now - BAN_TTL

    if File.exist?(ban_file)
      File.readlines(ban_file, chomp: true).each do |line|
        ip, ts = line.split("\t", 2)
        next if ip.blank?
        banned_at = ts ? Time.parse(ts) : (Time.now - BAN_TTL + 1)
        AUTO_BANNED[ip] = banned_at if banned_at > cutoff
      end
    end

    if File.exist?(manual_ban_file)
      File.readlines(manual_ban_file, chomp: true).each do |line|
        line = line.sub(/#.*/, "").strip
        next if line.blank?
        MANUAL_BANNED << IPAddr.new(line)
      rescue IPAddr::InvalidAddressError
        Rails.logger.warn "[ip-blocker] invalid entry in manual_bans.txt: #{line}"
      end
    end
  rescue => e
    Rails.logger.error "[ip-blocker] failed to load ban files: #{e.message}"
  end

  def self.auto_ban!(ip_str)
    now = Time.now
    AUTO_BANNED_MUTEX.synchronize do
      AUTO_BANNED[ip_str] = now
      File.open(ban_file, "a") { |f| f.puts "#{ip_str}\t#{now.iso8601}" }
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = remote_ip(env)
    path = env["PATH_INFO"]

    if ip
      ip_str = ip.to_s

      if blocked_cidr?(ip) || manual_banned?(ip) || auto_banned?(ip_str)
        ua = env["HTTP_USER_AGENT"].to_s[0, 100]
        Rails.logger.warn "[ip-blocker] blocked #{ip_str} #{env['REQUEST_METHOD']} #{path} UA:#{ua}"
        return [403, { "Content-Type" => "text/plain" }, ["Forbidden\n"]]
      end

      if honeypot?(path)
        self.class.auto_ban!(ip_str)
        Rails.logger.warn "[ip-blocker] auto-banned #{ip_str} for #{path} UA:#{env['HTTP_USER_AGENT'].to_s[0, 100]}"
        return [403, { "Content-Type" => "text/plain" }, ["Forbidden\n"]]
      end
    end

    @app.call(env)
  end

  private

  def remote_ip(env)
    forwarded = env["HTTP_X_FORWARDED_FOR"]
    if forwarded.present?
      IPAddr.new(forwarded.split(",").first.strip)
    else
      IPAddr.new(env["REMOTE_ADDR"])
    end
  rescue IPAddr::InvalidAddressError
    nil
  end

  def blocked_cidr?(addr)
    BLOCKED_CIDRS.any? { |cidr| cidr.include?(addr) }
  end

  def manual_banned?(addr)
    MANUAL_BANNED.any? { |cidr| cidr.include?(addr) }
  end

  def auto_banned?(ip_str)
    AUTO_BANNED_MUTEX.synchronize do
      banned_at = AUTO_BANNED[ip_str]
      return false unless banned_at
      return true if Time.now - banned_at < BAN_TTL
      AUTO_BANNED.delete(ip_str)  # expired, clean up
      false
    end
  end

  def honeypot?(path)
    HONEYPOT_PATHS.any? { |h| path.start_with?(h) }
  end
end
