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
    resources :citizens, except: :destroy do
      resources :household_members, only: %i[create destroy], shallow: true
    end
    resources :households, only: %i[index show] do
      collection do
        get :map
        get :markers
      end
      resources :household_members, only: %i[create destroy], shallow: true
      resources :household_animals, only: %i[create destroy], shallow: true
    end
    resources :appointments, except: :destroy do
      member do
        post :check_in
        post :complete
        post :cancel
        post :reschedule
      end
      collection do
        get :reception
        get :select_facility
      end
    end
    resources :ledi_batches, only: %i[index show]

    namespace :indicators do
      root "dashboard#show"
      resources :teams, only: :show
      get "projections", to: "projections#show"
    end
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
        resources :appointments, only: %i[index create] do
          collection do
            get :slots
          end
          member do
            post :cancel
            post :reschedule
          end
        end
        resources :immunization_records, only: :index
      end
    end
  end
end
