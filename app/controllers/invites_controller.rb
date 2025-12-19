class InvitesController < ApplicationController
  before_action :require_login
  before_action :set_invite, only: [ :destroy ]

  def create
    authorize Invite
    @invite = Invite.new(invite_params)
    @invite.created_by = current_user

    if @invite.save
      redirect_to users_path, notice: "Invite link created successfully."
    else
      redirect_to users_path, alert: "Failed to create invite link."
    end
  end

  def destroy
    authorize @invite
    @invite.destroy
    redirect_to users_path, notice: "Invite deleted."
  end

  private

  def set_invite
    @invite = Invite.find(params[:id])
  end

  def invite_params
    params.require(:invite).permit(:email, :role)
  end
end
