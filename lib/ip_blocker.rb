require 'ipaddr'

# Blocks requests from known AI crawler and scraper IP ranges.
# To add IPs, append to BLOCKED_CIDRS and redeploy.
# To find offenders: check production logs for suspicious crawl patterns.
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

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = remote_ip(env)

    if ip && blocked?(ip)
      ua = env["HTTP_USER_AGENT"].to_s.truncate(100)
      Rails.logger.warn "[ip-blocker] blocked #{ip} #{env['REQUEST_METHOD']} #{env['PATH_INFO']} UA:#{ua}"
      return [403, { "Content-Type" => "text/plain" }, ["Forbidden\n"]]
    end

    @app.call(env)
  end

  private

  def remote_ip(env)
    # Respect X-Forwarded-For set by kamal-proxy
    forwarded = env["HTTP_X_FORWARDED_FOR"]
    if forwarded.present?
      IPAddr.new(forwarded.split(",").first.strip)
    else
      IPAddr.new(env["REMOTE_ADDR"])
    end
  rescue IPAddr::InvalidAddressError
    nil
  end

  def blocked?(addr)
    BLOCKED_CIDRS.any? { |cidr| cidr.include?(addr) }
  end
end
