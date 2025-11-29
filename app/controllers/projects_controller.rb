class ProjectsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    @project = Project.find_by!(key: params[:key])
    @environments = @project.environments.includes(:drift_checks).order(:name)
  end

  private

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
