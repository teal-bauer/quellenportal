require 'ipaddr'
require 'set'

# Blocks requests from known AI crawler/scraper IP ranges,
# and auto-bans IPs that probe honeypot paths (scanners, exploit kits).
#
# Auto-bans are in-memory per worker process and reset on restart.
# To permanently block an IP, add it to BLOCKED_CIDRS and redeploy.
class IpBlocker
  BLOCKED_CIDRS = [
    # ByteDance / Bytespider
    "114.119.128.0/18",
    "2401:b180::/32",

    # Omgili / Webz.io
    "5.188.134.0/24",

    # PetalBot (Huawei)
    "119.28.0.0/16",
    "119.29.0.0/16",

    # Majestic / MJ12bot
    "91.108.4.0/22",

    # Manual blocks
    "74.7.227.140/32",
  ].map { |cidr| IPAddr.new(cidr) }.freeze

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

  AUTO_BANNED = Set.new
  AUTO_BANNED_MUTEX = Mutex.new

  def self.auto_ban!(ip_str)
    AUTO_BANNED_MUTEX.synchronize { AUTO_BANNED.add(ip_str) }
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = remote_ip(env)
    path = env["PATH_INFO"]

    if ip
      ip_str = ip.to_s

      if blocked_cidr?(ip) || auto_banned?(ip_str)
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

  def auto_banned?(ip_str)
    AUTO_BANNED_MUTEX.synchronize { AUTO_BANNED.include?(ip_str) }
  end

  def honeypot?(path)
    HONEYPOT_PATHS.any? { |h| path.start_with?(h) }
  end
end
