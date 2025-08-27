require "sidekiq"

db_index = { "development" => 0, "test" => 1, "production" => 2 }[Rails.env] || 0
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/#{db_index}")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  # Hook d’erreurs → log (et Sentry si présent)
  config.error_handlers << proc { |ex, ctx| Rails.logger.error("[Sidekiq] #{ex.class}: #{ex.message} | #{ctx.inspect}") }
  # Sentry (optionnel)
  # if defined?(Sentry)
  #   config.error_handlers << proc { |ex, ctx| Sentry.capture_exception(ex, extra: { sidekiq: ctx }) }
  # end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
