class EnvironmentsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    @project = Project.find_by!(key: params[:project_key])
    @environment = @project.environments.find_by!(key: params[:key])
    @drift_checks = @environment.drift_checks.order(created_at: :desc)
    # Environment-level channel takes precedence, otherwise fall back to project-level
    @slack_channel = @environment.notification_channels.for_type("slack").enabled.first ||
                     @project.notification_channels.for_type("slack").enabled.first
  end

  private

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
