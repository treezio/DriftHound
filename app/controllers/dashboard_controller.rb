class DashboardController < ApplicationController
  def index
    @projects = Project.includes(environments: :drift_checks).order(:name)
    @project_environments = []
    @projects.each do |project|
      project.environments.order(:name).each do |env|
        @project_environments << [ project, env ]
      end
    end
    # Count each project/environment pair by environment status (per project in environment)
    @project_environment_status_counts = Hash.new(0)
    @project_environments.each do |(_project, env)|
      @project_environment_status_counts[env.last_check_status] += 1
    end
  end
end
