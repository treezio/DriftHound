class NotificationService
  # Time threshold for re-notifying about persistent issues (24 hours)
  LATERAL_NOTIFICATION_THRESHOLD = 24.hours

  def initialize(environment, old_status, new_status)
    @environment = environment
    @old_status = old_status.to_s
    @new_status = new_status.to_s
  end

  def call
    return unless should_notify?

    notification = build_notification
    deliver_to_all_channels(notification)
  end

  private

  def should_notify?
    # Always notify on significant state changes
    return true if significant_change?

    # For lateral moves (drift->drift, error->error), check if enough time has passed
    return true if lateral_move? && should_notify_lateral_move?

    false
  end

  def significant_change?
    # Status actually changed and it's not a lateral move
    status_changed? && !lateral_move?
  end

  def status_changed?
    @old_status != @new_status
  end

  def lateral_move?
    # drift -> drift or error -> error (same severity)
    (@old_status == "drift" && @new_status == "drift") ||
    (@old_status == "error" && @new_status == "error")
  end

  def should_notify_lateral_move?
    # Check each enabled channel to see if we should re-notify
    enabled_channels.any? { |channel| should_notify_for_channel?(channel) }
  end

  def should_notify_for_channel?(channel)
    state = NotificationState.find_by(
      environment: @environment,
      channel: channel.channel_type
    )

    # If no state exists, this is the first notification
    return true unless state

    # If we've never notified this status, notify now
    return true unless state.last_notified_status

    # Get the last time we sent a notification
    last_sent = state.metadata&.dig("last_sent_at")
    return true unless last_sent

    # Notify if enough time has passed since last notification
    Time.current - Time.parse(last_sent) >= LATERAL_NOTIFICATION_THRESHOLD
  rescue StandardError => e
    Rails.logger.error("Error checking notification timing: #{e.message}")
    # Default to notifying on error
    true
  end

  def build_notification
    Notification.new(
      environment: @environment,
      event_type: determine_event_type,
      old_status: @old_status,
      new_status: @new_status
    )
  end

  def determine_event_type
    # Determine event type based on status transitions
    if @new_status == "error" && @old_status != "error"
      :error_detected
    elsif @old_status == "error" && @new_status == "ok"
      :error_resolved
    elsif @old_status == "error" && @new_status == "drift"
      :error_resolved # Degraded but improved
    elsif @new_status == "drift" && @old_status != "drift"
      :drift_detected
    elsif @old_status == "drift" && @new_status == "ok"
      :drift_resolved
    else
      :unknown
    end
  end

  def deliver_to_all_channels(notification)
    enabled_channels.each do |channel|
      # For lateral moves, only deliver to channels where enough time has passed
      next if lateral_move? && !should_notify_for_channel?(channel)

      NotificationDelivery.deliver(
        notification: notification,
        channel: channel
      )
    end
  end

  def enabled_channels
    # Get channels configured at environment level or fallback to project level
    channels = @environment.notification_channels.enabled
    channels = @environment.project.notification_channels.enabled if channels.empty?
    channels
  end
end
