# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :web do
    root "dashboard#show"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :health_facilities, except: :destroy
    resources :care_teams, except: :destroy
    resources :micro_areas, except: :show
    resources :users, only: %i[index new create edit update]
    resources :citizens, only: %i[index show]
    resources :households, only: %i[index show] do
      collection do
        get :map
        get :markers
      end
      resources :household_animals, only: %i[create destroy], shallow: true
    end
    resources :ledi_batches, only: %i[index show]
  end

  namespace :api, defaults: { format: :json } do
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
