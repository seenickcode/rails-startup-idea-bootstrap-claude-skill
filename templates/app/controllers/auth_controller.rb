class AuthController < ApplicationController
  def new
  end

  def create
    email = params[:email].to_s.strip.downcase
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to signin_path, alert: "That email doesn't look right."
    end
    AuthService.start_sign_in!(email:, newsletter: params[:newsletter] == "1")
    redirect_to signin_path, notice: "Check your email for a sign-in link."
  end

  def verify
    result = AuthService.complete_sign_in!(token: params[:token].to_s)
    if result
      cookies.permanent[:user_email] = result[:user].email
      cookies.permanent[:session_token] = result[:session_token]
      redirect_to root_path, notice: "You're signed in."
    else
      redirect_to signin_path, alert: "That link is invalid or expired. Request a new one."
    end
  end

  def destroy
    cookies.delete(:user_email)
    cookies.delete(:session_token)
    redirect_to root_path, notice: "Signed out."
  end
end
