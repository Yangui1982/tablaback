require "sidekiq/web"
require "rack/session"

# API-only : nécessaire pour l'UI Sidekiq
Sidekiq::Web.use Rack::Session::Cookie, secret: Rails.application.secret_key_base

Rails.application.routes.draw do
  devise_for :users, skip: [:sessions, :registrations, :passwords, :confirmations]

  namespace :api do
    namespace :v1 do
      post   "auth/login",  to: "auth#login"
      delete "auth/logout", to: "auth#logout"
      get    "health",      to: "health#show"

      resources :projects do
        resources :scores do
          member do
            post :import
            get  :midi            # stream le mix (génère si besoin)
            post :render_midi     # force la régénération du mix
            get  :midi_by_tracks  # lecture de certaines pistes seulement
          end
          resources :tracks, only: %i[index show create update destroy]
        end
      end

      resources :uploads, only: :create
    end
  end

  # --- Sidekiq Web UI ---
  if Rails.env.development? || Rails.env.test?
    # Libre en dev/test
    mount Sidekiq::Web => "/sidekiq"
  else
    # Prod/Staging : protégé par BasicAuth
    sidekiq_user = ENV["SIDEKIQ_USER"]
    sidekiq_pass = ENV["SIDEKIQ_PASSWORD"]

    if sidekiq_user.present? && sidekiq_pass.present?
      Sidekiq::Web.use Rack::Auth::Basic do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u, sidekiq_user) &&
          ActiveSupport::SecurityUtils.secure_compare(p, sidekiq_pass)
      end
      mount Sidekiq::Web => "/sidekiq"
    end
    # Sinon : ne monte pas le dashboard (sécurité par défaut)
  end
end
