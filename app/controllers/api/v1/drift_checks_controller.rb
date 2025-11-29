module Api
  module V1
    class DriftChecksController < BaseController
      def create
        project = Project.find_or_create_by_key(params[:project_key])
        environment = Environment.find_or_create_by_key(project, params[:environment_key])

        drift_check = environment.drift_checks.create!(drift_check_params)

        render json: {
          id: drift_check.id,
          project_key: project.key,
          environment_key: environment.key,
          status: drift_check.status,
          created_at: drift_check.created_at
        }, status: :created
      end

      private

      def drift_check_params
        params.permit(:status, :add_count, :change_count, :destroy_count, :duration, :raw_output)
      end
    end
  end
end
