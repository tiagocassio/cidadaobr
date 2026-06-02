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
    resources :households, except: :destroy do
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
        post :no_show
        post :reschedule
      end
      collection do
        get :reception
        get :utilization
        get :select_facility
        get :walk_in
        post :walk_in
      end
    end
    resources :ledi_batches, only: %i[index show]

    namespace :indicators do
      root "dashboard#show"
      resources :teams, only: :show
      get "projections", to: "projections#show"
    end

    namespace :stock do
      resources :immunobiological_products, except: :destroy
      resources :supply_items, except: :destroy
      resources :immunobiological_lots, only: %i[index new create]
      resources :team_supply_dispatches, only: %i[index show]
    end

    namespace :campaigns do
      resources :vaccination_campaigns, only: %i[index show new create edit update] do
        # collection: new campaign wizard (no id); member: resume wizard on existing campaign
        collection do
          get "wizard/:step", action: :wizard, as: :wizard, constraints: { step: /[1-4]/ }
        end
        member do
          get "wizard/:step", action: :wizard, as: :wizard, constraints: { step: /[1-4]/ }
          patch "wizard/:step", action: :update_wizard, as: :update_wizard, constraints: { step: /[1-4]/ }
          get :preview_targets
          get :preview_provisioning
          post :calculate_provisioning
          post :build_targets
          post :publish
        end
      end
      resources :home_visit_campaigns, only: %i[index show new create] do
        member do
          post :build_targets
          post :generate_routes
          post :clear_routes
          post :publish_routes
          get :preview_provisioning
          post :calculate_provisioning
          post :reserve_provisioning
          patch :update_provisioning
          post :dispatch_supplies
          get :route_map
        end
      end
    end
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      namespace :field do
        get "health", to: "health#show"
        post "auth", to: "auth#create"
        post "clinical_records/:id/validate", to: "clinical_records#validate"
        resources :campaigns, only: %i[index show]
        resources :visit_routes, only: %i[index show]
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

      get "reference/manifest", to: "reference#manifest"
      get "reference/domains/:key", to: "reference#domain"
      get "reference/ledi/catalog", to: "reference#ledi_catalog"
    end
  end
end
