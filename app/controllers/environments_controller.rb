class EnvironmentsController < ApplicationController
  before_action :set_project_and_environment
  before_action :require_login, only: [ :destroy ]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    authorize @environment
    @drift_checks = @environment.drift_checks.order(created_at: :desc)
    # Environment-level channel takes precedence, otherwise fall back to project-level
    @slack_channel = @environment.notification_channels.for_type("slack").enabled.first ||
                     @project.notification_channels.for_type("slack").enabled.first
  end

  def destroy
    authorize @environment
    environment_name = @environment.name
    @environment.destroy
    redirect_to project_path(@project.key), notice: "Environment '#{environment_name}' has been deleted"
  end

  private

  def set_project_and_environment
    @project = Project.find_by!(key: params[:project_key])
    @environment = @project.environments.find_by!(key: params[:key])
  end

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
