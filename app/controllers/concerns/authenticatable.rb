# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_membership if respond_to?(:helper_method)
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id], active: true)
  end

  def current_membership
    return @current_membership if defined?(@current_membership)

    municipality_id = session.dig(:tenant, "municipality_id")
    @current_membership = current_user&.active_membership_for(municipality_id)
  end

  def authenticate!
    return if current_user && current_membership

    respond_to_unauthorized
  end

  def respond_to_unauthorized
    if request.format.json? || request.path.start_with?("/api/")
      render json: { error: "Unauthorized" }, status: :unauthorized
    else
      redirect_to web_login_path, alert: "Faça login para continuar."
    end
  end

  def sign_in_user!(user, membership)
    reset_session
    session[:user_id] = user.id
    session[:tenant] = {
      "municipality_id" => membership.municipality_id,
      "scope" => membership.scope,
      "health_facility_id" => membership.health_facility_id,
      "team_ids" => user.team_ids_for(membership.municipality_id)
    }
  end

  def sign_out_user!
    reset_session
  end
end
