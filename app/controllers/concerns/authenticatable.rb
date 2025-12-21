module Authenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?, :public_mode?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def public_mode?
    Rails.application.config.public_mode
  end

  def require_login
    unless logged_in?
      flash[:alert] = "You must be logged in to perform this action"
      redirect_to login_path
    end
  end

  # Requires login only when not in public mode
  # Use this for read-only actions that should be public when public_mode is enabled
  def require_login_unless_public
    require_login unless public_mode?
  end
end
