class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  helper_method :current_user_email, :signed_in?

  # Fast path: cookie only, no DB hit. Use for display.
  def current_user_email = cookies[:user_email]
  def signed_in? = current_user_email.present?

  # Slow path: validates the session token against the DB. Use before
  # anything sensitive.
  def verified_user
    @verified_user ||= AuthService.verify_session(cookies[:user_email], cookies[:session_token])
  end

  def require_verified_user
    redirect_to signin_path, alert: "Please sign in." unless verified_user
  end
end
