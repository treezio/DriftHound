class ProjectsController < ApplicationController
  before_action :set_project
  before_action :require_login_unless_public, only: [ :show ]
  before_action :require_login, only: [ :destroy ]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    authorize @project
    @environments = @project.environments.includes(:drift_checks).order(:name)
    @slack_channel = @project.notification_channels.for_type("slack").enabled.first
  end

  def destroy
    authorize @project
    project_name = @project.name
    @project.destroy
    redirect_to root_path, notice: "Project '#{project_name}' and all its environments have been deleted"
  end

  private

  def set_project
    @project = Project.find_by!(key: params[:key])
  end

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
