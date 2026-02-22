require 'ipaddr'

# Blocks requests from known AI crawler/scraper IP ranges,
# and auto-bans IPs that probe honeypot paths (scanners, exploit kits).
#
# Three ban sources:
#   CONFIG_BANNED  — config/manual_bans.txt, committed to git, read-only at runtime
#   RUNTIME_BANNED — storage/manual_bans.txt, persistent volume, editable via admin UI
#   AUTO_BANNED    — storage/banned_ips.txt, honeypot hits, expire after 30 days
class IpBlocker
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

  CONFIG_BANNED  = {}  # raw_str => IPAddr, from config/manual_bans.txt (never written)
  RUNTIME_BANNED = {}  # raw_str => IPAddr, from storage/manual_bans.txt (editable)
  RUNTIME_BANNED_MUTEX = Mutex.new

  AUTO_BANNED = {}     # ip_str => banned_at (Time), expires after BAN_TTL
  AUTO_BANNED_MUTEX = Mutex.new

  # -- File paths --

  def self.auto_ban_file
    Rails.root.join("storage", "banned_ips.txt")
  end

  def self.config_ban_file
    Rails.root.join("config", "manual_bans.txt")
  end

  def self.runtime_ban_file
    Rails.root.join("storage", "manual_bans.txt")
  end

  # -- Boot loader --

  # Called once at boot from config/initializers/ip_blocker.rb
  def self.load_bans!
    cutoff = Time.now - BAN_TTL

    if File.exist?(auto_ban_file)
      File.readlines(auto_ban_file, chomp: true).each do |line|
        ip, ts = line.split("\t", 2)
        next if ip.blank?
        banned_at = ts ? Time.parse(ts) : (Time.now - BAN_TTL + 1)
        AUTO_BANNED[ip] = banned_at if banned_at > cutoff
      end
    end

    load_ban_file(config_ban_file, CONFIG_BANNED)
    load_ban_file(runtime_ban_file, RUNTIME_BANNED)
  rescue => e
    Rails.logger.error "[ip-blocker] failed to load ban files: #{e.message}"
  end

  # -- Mutation methods --

  def self.auto_ban!(ip_str)
    now = Time.now
    AUTO_BANNED_MUTEX.synchronize do
      AUTO_BANNED[ip_str] = now
      File.open(auto_ban_file, "a") { |f| f.puts "#{ip_str}\t#{now.iso8601}" }
    end
  end

  def self.remove_auto_ban!(ip_str)
    AUTO_BANNED_MUTEX.synchronize do
      AUTO_BANNED.delete(ip_str)
      rewrite_auto_ban_file
    end
  end

  def self.add_manual_ban!(raw)
    raw = raw.strip
    addr = IPAddr.new(raw)  # raises IPAddr::InvalidAddressError if bad
    RUNTIME_BANNED_MUTEX.synchronize do
      RUNTIME_BANNED[raw] = addr
      File.open(runtime_ban_file, "a") { |f| f.puts raw }
    end
  end

  def self.remove_manual_ban!(raw)
    RUNTIME_BANNED_MUTEX.synchronize do
      RUNTIME_BANNED.delete(raw)
      rewrite_runtime_ban_file
    end
  end

  # -- Rack middleware --

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = remote_ip(env)
    path = env["PATH_INFO"]

    if ip
      ip_str = ip.to_s

      if manual_banned?(ip) || auto_banned?(ip_str)
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

  private_class_method def self.load_ban_file(path, store)
    return unless File.exist?(path)
    File.readlines(path, chomp: true).each do |line|
      line = line.sub(/#.*/, "").strip
      next if line.blank?
      store[line] = IPAddr.new(line)
    rescue IPAddr::InvalidAddressError
      Rails.logger.warn "[ip-blocker] invalid entry in #{path}: #{line}"
    end
  end

  private_class_method def self.rewrite_auto_ban_file
    lines = AUTO_BANNED.map { |ip, t| "#{ip}\t#{t.iso8601}" }
    File.write(auto_ban_file, lines.join("\n") + (lines.any? ? "\n" : ""))
  end

  private_class_method def self.rewrite_runtime_ban_file
    File.write(runtime_ban_file, RUNTIME_BANNED.keys.join("\n") + (RUNTIME_BANNED.any? ? "\n" : ""))
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

  def manual_banned?(addr)
    CONFIG_BANNED.any? { |_, cidr| cidr.include?(addr) } ||
      RUNTIME_BANNED_MUTEX.synchronize { RUNTIME_BANNED.any? { |_, cidr| cidr.include?(addr) } }
  end

  def auto_banned?(ip_str)
    AUTO_BANNED_MUTEX.synchronize do
      banned_at = AUTO_BANNED[ip_str]
      return false unless banned_at
      return true if Time.now - banned_at < BAN_TTL
      AUTO_BANNED.delete(ip_str)  # expired
      false
    end
  end

  def honeypot?(path)
    HONEYPOT_PATHS.any? { |h| path.start_with?(h) }
  end
end
