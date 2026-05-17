Rack::Attack.cache.store = Rails.cache

# Allow everything in development
if Rails.env.development?
  Rack::Attack.enabled = false
  return
end

# Hard-block AI/SEO crawler UAs — they either ignore robots.txt or use UA strings
# we haven't disallowed there. Defense in depth.
BAD_UA_RE = /
  Claude-SearchBot | ClaudeBot | anthropic-ai | Claude-Web |
  GPTBot | ChatGPT-User | OAI-SearchBot |
  PerplexityBot | cohere-ai | YouBot |
  Bytespider |
  meta-externalagent | FacebookBot |
  CCBot | Applebot-Extended |
  AhrefsBot | SemrushBot | MJ12bot | DotBot | BLEXBot | Barkrowler |
  DataForSeoBot | PetalBot | Seekport | SEOkicks | Seobility |
  Amazonbot | Diffbot | ImagesiftBot | omgili | omgilibot |
  TurnitinBot | VelenPublicWebCrawler | Scrapy | Timpibot |
  Kangaroo\sBot
/ix.freeze

Rack::Attack.blocklist("bad-ua") do |req|
  ua = req.user_agent.to_s
  !ua.empty? && BAD_UA_RE.match?(ua)
end

# Throttle: 60 req/min per IP across the whole app
Rack::Attack.throttle("req/ip", limit: 60, period: 60) do |req|
  req.ip unless req.path.start_with?("/assets/")
end

# Tighter limit on search queries (hits Meilisearch)
Rack::Attack.throttle("search/ip", limit: 20, period: 60) do |req|
  req.ip if req.path == "/" && req.get? && req.params["q"].present?
end

# Log blocked/throttled requests
ActiveSupport::Notifications.subscribe("rack.attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn "[rack-attack] #{req.env['rack.attack.match_type']} #{req.ip} " \
                    "#{req.request_method} #{req.fullpath} " \
                    "UA:#{req.user_agent.to_s.truncate(100)}"
end
