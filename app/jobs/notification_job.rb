class NotificationJob < ApplicationJob
  queue_as :default

  def perform(environment_id:, old_status:, new_status:)
    environment = Environment.find(environment_id)

    NotificationService.new(environment, old_status, new_status).call
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn("NotificationJob: Environment not found: #{environment_id}")
  end
end
