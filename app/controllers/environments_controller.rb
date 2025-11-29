class EnvironmentsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    @project = Project.find_by!(key: params[:project_key])
    @environment = @project.environments.find_by!(key: params[:key])
    @drift_checks = @environment.drift_checks.order(created_at: :desc)
  end

  private

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
