# frozen_string_literal: true

module Web
  class SessionsController < BaseController
    skip_before_action :authenticate!, only: %i[new create]

    def new
    end

    def create
      credentials = session_params
      user = User.find_by(email: credentials[:email]&.downcase)
      membership = user&.active_membership_for(credentials[:municipality_id])

      if user&.authenticate(credentials[:password]) && membership
        sign_in_user!(user, membership)
        redirect_to web_root_path, notice: t("cidadaobr.sessions.flash.signed_in")
      else
        flash.now[:alert] = t("cidadaobr.sessions.flash.invalid_credentials")
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out_user!
      redirect_to web_login_path, notice: t("cidadaobr.sessions.flash.signed_out")
    end

    private

    def session_params
      params.permit(:email, :password, :municipality_id)
    end
  end
end
