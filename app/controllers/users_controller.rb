class UsersController < ApplicationController
  before_action :require_login
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    authorize User
    @users = policy_scope(User).order(:email)
    @invites = Invite.available.includes(:created_by).order(created_at: :desc)
    @new_invite = Invite.new
  end

  def new
    authorize User
    @user = User.new
  end

  def create
    authorize User
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "User '#{@user.email}' was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    if @user.update(user_params)
      redirect_to users_path, notice: "User '#{@user.email}' was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user

    if @user == current_user
      redirect_to users_path, alert: "You cannot delete yourself."
    else
      email = @user.email
      @user.destroy
      redirect_to users_path, notice: "User '#{email}' was successfully deleted."
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role)
  end
end
