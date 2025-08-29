class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: :login
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped


  def login
    user = User.find_by(email: params[:email])
    if user&.valid_password?(params[:password])
      sign_in(user, store: false)
      render json: { ok: true, user: { id: user.id, email: user.email } }
    else
      render json: { error: 'invalid_credentials', "email ou mot de passe incorrect" }, status: :unauthorized
    end
  end

  def logout
    sign_out(current_user)
    head :no_content
  end
end
