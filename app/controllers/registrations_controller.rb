class RegistrationsController < ApplicationController
  before_action :redirect_if_logged_in
  before_action :set_invite
  before_action :verify_invite

  def new
    @user = User.new(email: @invite.email)
  end

  def create
    @user = User.new(user_params)
    @user.email = @invite.email
    @user.role = @invite.role

    if @user.save
      @invite.mark_as_used!
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to DriftHound! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_logged_in
    redirect_to root_path if logged_in?
  end

  def set_invite
    @invite = Invite.find_by(token: params[:token])
  end

  def verify_invite
    if @invite.nil?
      redirect_to login_path, alert: "Invalid invite link."
    elsif @invite.used?
      redirect_to login_path, alert: "This invite link has already been used."
    elsif @invite.expired?
      redirect_to login_path, alert: "This invite link has expired."
    end
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
