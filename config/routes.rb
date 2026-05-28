Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :web do
    root "dashboard#show"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"
  end

  namespace :api do
    namespace :v1 do
      namespace :field do
        get "health", to: "health#show"
        post "auth", to: "auth#create"
        post "clinical_records/:id/validate", to: "clinical_records#validate"
      end

      namespace :citizen do
        get "health", to: "health#show"
        post "auth", to: "auth#create"
      end
    end
  end
end
