# frozen_string_literal: true

module Web
  class SessionsController < BaseController
    def new
    end

    def create
      user = User.find_by(email: params[:email]&.downcase)
      membership = user&.active_membership_for(params[:municipality_id])

      if user&.authenticate(params[:password]) && membership
        sign_in_user!(user, membership)
        redirect_to web_root_path, notice: "Login realizado com sucesso."
      else
        flash.now[:alert] = "Credenciais inválidas."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out_user!
      redirect_to web_login_path, notice: "Sessão encerrada."
    end
  end
end
