# frozen_string_literal: true

module Web
  class UsersController < BaseController
    before_action :require_municipality_scope!
    before_action :set_user, only: %i[edit update]
    before_action :set_health_facilities, only: %i[new create edit update]

    def index
      memberships = UserMunicipalityMembership
        .includes(:user, :health_facility)
        .joins(:user)
        .where(municipality_id: current_municipality.id)
        .order(users: { full_name: :asc })
      @pagy, @memberships = pagy(memberships)
    end

    def new
      @user = User.new
      @membership = UserMunicipalityMembership.new(scope: "facility", role_code: "facility_manager")
    end

    def create
      @user = User.new(user_params)
      @membership = @user.user_municipality_memberships.build(sanitized_membership_params(for_create: true))
      @membership.municipality = current_municipality

      result = CommandBus.dispatch(
        Platform::Commands::RegisterMunicipalUser,
        user: @user,
        membership: @membership
      )

      if result.success
        redirect_to web_users_path, notice: t("cidadaobr.users.flash.created")
      else
        @membership = @user.user_municipality_memberships.first || UserMunicipalityMembership.new(sanitized_membership_params)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @membership = @user.user_municipality_memberships.find_by!(municipality_id: current_municipality.id)
    end

    def update
      @membership = @user.user_municipality_memberships.find_by!(municipality_id: current_municipality.id)

      result = CommandBus.dispatch(
        Platform::Commands::UpdateMunicipalUser,
        user: @user,
        membership: @membership,
        user_attributes: user_update_params,
        membership_attributes: sanitized_membership_params
      )

      if result.success
        redirect_to web_users_path, notice: t("cidadaobr.users.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.joins(:user_municipality_memberships)
        .where(user_municipality_memberships: { municipality_id: current_municipality.id })
        .find(params[:id])
    end

    def set_health_facilities
      @health_facilities = scoped_health_facilities.order(:name)
    end

    def user_params
      params.require(:user).permit(:email, :full_name, :password, :password_confirmation)
    end

    def user_update_params
      permitted = params.require(:user).permit(:email, :full_name, :active, :password, :password_confirmation)
      permitted.delete(:password) if permitted[:password].blank?
      permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
      permitted
    end

    def membership_params
      params.require(:user_municipality_membership).permit(:scope, :role_code, :health_facility_id, :active)
    end

    def sanitized_membership_params(for_create: false)
      permitted = membership_params
      permitted = permitted.except(:active) if for_create
      unless UserMunicipalityMembership::WEB_SCOPES.include?(permitted[:scope])
        permitted[:scope] = "invalid"
      end
      unless UserMunicipalityMembership::WEB_ROLE_CODES.include?(permitted[:role_code])
        permitted[:role_code] = "invalid"
      end
      if permitted[:scope] == "facility"
        facility = scoped_health_facilities.find_by(id: permitted[:health_facility_id])
        permitted[:health_facility_id] = facility&.id
      else
        permitted[:health_facility_id] = nil
      end
      permitted
    end
  end
end
