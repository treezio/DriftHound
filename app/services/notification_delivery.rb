class NotificationDelivery
  ADAPTERS = {
    "slack" => "Notifiers::Slack"
  }.freeze

  def self.deliver(notification:, channel:)
    new(notification, channel).deliver
  end

  def initialize(notification, channel)
    @notification = notification
    @channel = channel
    @adapter_class = resolve_adapter(@channel.channel_type)
  end

  def deliver
    return unless @adapter_class

    notification_state = find_or_create_state

    if @notification.should_update_existing? && notification_state.external_id.present?
      @adapter_class.update(notification_state, @notification, @channel.config)
    else
      @adapter_class.deliver(@notification, @channel.config, notification_state)
    end
  rescue StandardError => e
    Rails.logger.error("Notification delivery failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Could send to error tracking service (Sentry, etc.)
  end

  private

  def resolve_adapter(channel_type)
    adapter_name = ADAPTERS[channel_type]
    return nil unless adapter_name

    adapter_name.constantize
  rescue NameError
    Rails.logger.warn("Notification adapter not found: #{adapter_name}")
    nil
  end

  def find_or_create_state
    NotificationState.find_or_create_by!(
      environment: @notification.environment,
      channel: @channel.channel_type
    )
  end
end
