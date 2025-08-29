enabled_by_env =
  ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("RACK_ATTACK_ENABLED", (Rails.env.production? || Rails.env.staging?).to_s)
  )

Rack::Attack.enabled = enabled_by_env
Rack::Attack.cache.store = Rails.cache

Rack::Attack.safelist("allow-localhost-nonprod") do |req|
  !Rails.env.production? && ["127.0.0.1", "::1"].include?(req.ip)
end

Rack::Attack.safelist("healthchecks") do |req|
  req.get? && (req.path == "/up" || req.path == "/api/v1/health")
end

Rack::Attack.safelist("sidekiq-web") do |req|
  req.path.start_with?("/sidekiq")
end

Rack::Attack.blocklist("env-blocked-ips") do |req|
  blocked = ENV["BLOCKED_IPS"]&.split(",")&.map!(&:strip)
  blocked&.include?(req.ip)
end

Rack::Attack.throttle("req/ip", limit: 120, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api/")
end

Rack::Attack.throttle("login/ip", limit: 10, period: 1.minute) do |req|
  req.ip if req.post? && req.path == "/api/v1/auth/login"
end

Rack::Attack.throttle("login/email", limit: 5, period: 1.minute) do |req|
  next unless req.post? && req.path == "/api/v1/auth/login"

  email = begin
    body = req.body.read
    req.body.rewind
    JSON.parse(body)["email"]
  rescue
    req.params["email"]
  ensure
    req.body.rewind
  end

  email&.downcase
end


Rack::Attack.throttle("uploads/ip", limit: 20, period: 10.minutes) do |req|
  req.ip if req.post? && req.path == "/api/v1/uploads"
end

Rack::Attack.throttle("imports/ip", limit: 12, period: 10.minutes) do |req|
  req.ip if req.post? && req.path.match?(%r{\A/api/v1/projects/[^/]+/scores/[^/]+/import\z})
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data  = request.env["rack.attack.match_data"] || {}
  rule_name   = request.env["rack.attack.matched"]
  now         = Time.now.utc
  retry_after = (match_data[:period] || 60).to_i

  headers = {
    "Content-Type"       => "application/json",
    "Retry-After"        => retry_after.to_s,
    "X-RateLimit-Limit"  => match_data[:limit].to_s,
    "X-RateLimit-Period" => retry_after.to_s,
    "X-RateLimit-Reset"  => (now + retry_after).to_i.to_s
  }

  body = {
    error: {
      code:   "rate_limited",
      detail: "Trop de requêtes. Réessaie plus tard.",
      meta:   {
        name: rule_name,
        limit: match_data[:limit],
        period_seconds: retry_after
      }
    }
  }.to_json

  [429, headers, [body]]
end
