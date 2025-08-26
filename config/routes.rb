Rails.application.routes.draw do
  devise_for :users, skip: [:sessions, :registrations, :passwords, :confirmations]

  namespace :api do
    namespace :v1 do
      post   'auth/login',  to: 'auth#login'
      delete 'auth/logout', to: 'auth#logout'

      resources :projects do
        resources :scores do
          member do
            post :import
          end
          resources :tracks, only: [:index, :show, :create, :update, :destroy]
        end
      end
      resources :uploads, only: :create
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
