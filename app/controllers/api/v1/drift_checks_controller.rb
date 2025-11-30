module Api
  module V1
    class DriftChecksController < BaseController
      def create
        project = Project.find_or_create_by_key(params[:project_key])
        environment = Environment.find_or_create_by_key(project, params[:environment_key])

        # Update or create notification channel if configuration is provided
        if params[:notification_channel].present?
          update_notification_channel(environment)
        end

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

      def update_notification_channel(environment)
        channel_params = params.require(:notification_channel)
                               .permit(:channel_type, :enabled, config: [ :channel ])

        # Find or initialize the notification channel
        channel = environment.notification_channels
                             .find_or_initialize_by(channel_type: channel_params[:channel_type])

        # Update enabled status if provided
        channel.enabled = channel_params[:enabled] if channel_params.key?(:enabled)

        # Update config
        channel.config ||= {}

        # For Slack, always use global token
        if channel_params[:channel_type] == "slack"
          global_slack_config = Rails.application.config.notifications[:slack]

          # Set channel from params or use global default
          if channel_params[:config].present? && channel_params[:config][:channel].present?
            channel.config["channel"] = channel_params[:config][:channel]
          else
            channel.config["channel"] ||= global_slack_config[:default_channel]
          end

          # Always use global token
          channel.config["token"] = global_slack_config[:token]
        end

        channel.save!
      end
    end
  end
end
