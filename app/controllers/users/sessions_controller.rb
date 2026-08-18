# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # def create
  #   self.resource = warden.authenticate!(auth_options)
  #   set_flash_message!(:notice, :signed_in)

  #   # Render modal sukses setelah login
  #   render partial: 'shared/success_modal', locals: {
  #     title: "Welcome Back!",
  #     message: "You have been authenticated successfully. Welcome to Vending Machine Kiosk ERP.",
  #     redirect_path: root_path
  #   }
  # end
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
