# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:3000").split(",")
    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization], # <- nécessaire pour lire le JWT côté browser
      max_age: 600

    resource "/rails/active_storage/*",
      headers: :any,
      methods: %i[get head options],
      expose: %w[Content-Disposition Content-Type],
      max_age: 600
  end
end
