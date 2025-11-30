# Base class for all notification channel adapters
# Subclasses must implement:
# - self.deliver(notification, config, state)
# - self.update(state, notification, config)

module Notifiers
end

class Notifiers::Base
  class NotImplementedError < StandardError; end

  def self.deliver(notification, config, state)
    raise NotImplementedError, "#{self} must implement #deliver"
  end

  def self.update(state, notification, config)
    raise NotImplementedError, "#{self} must implement #update"
  end

  protected

  # Helper to track successful delivery
  def self.track_delivery(state, external_id, notification)
    state.mark_sent!(
      external_id: external_id,
      status: notification.new_status,
      metadata: { sent_at: Time.current }
    )
  end

  # Helper to clear tracking when resolved
  def self.clear_tracking(state)
    state.mark_resolved!
  end

  # Build a basic text message for simple channels
  def self.build_text_message(notification)
    lines = []
    lines << "#{notification.icon} #{notification.title}"
    lines << ""
    lines << "Project: #{notification.details[:project]}"
    lines << "Environment: #{notification.details[:environment]}"
    lines << "Status: #{notification.details[:status]}"
    lines << "Changes: #{notification.details[:changes]}" if notification.details[:changes]
    lines << ""
    lines << "View details: #{notification.details[:url]}"

    lines.join("\n")
  end
end
