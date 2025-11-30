require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
  end

  test "does not notify when status hasn't changed" do
    service = NotificationService.new(@environment, "ok", "ok")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "does not notify on lateral move drift to drift" do
    @environment.update!(status: :drift)
    service = NotificationService.new(@environment, "drift", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "does not notify on lateral move error to error" do
    @environment.update!(status: :error)
    service = NotificationService.new(@environment, "error", "error")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "notifies when transitioning from ok to drift" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :drift_detected &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from ok to error" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "ok", "error")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :error_detected &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from drift to ok" do
    @environment.update!(status: :drift)
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "drift", "ok")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :drift_resolved &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from error to ok" do
    @environment.update!(status: :error)
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "error", "ok")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :error_resolved &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from error to drift (degraded but improved)" do
    @environment.update!(status: :error)
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "error", "drift")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :error_resolved &&
      args[:channel] == channel
    end

    service.call
  end

  test "uses environment-level channels if available" do
    # Project has one channel
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#project-alerts" }
    )

    # Environment has override
    env_channel = @environment.notification_channels.create!(
      channel_type: "email",
      enabled: true,
      config: { recipients: ["env@example.com"] }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    # Should only use environment channel, not project channel
    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:channel] == env_channel
    end

    service.call
  end

  test "falls back to project-level channels when environment has none" do
    project_channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#project-alerts" }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:channel] == project_channel
    end

    service.call
  end

  test "only uses enabled channels" do
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: false,
      config: { channel: "#disabled" }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "delivers to multiple channels if configured" do
    slack_channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    email_channel = @project.notification_channels.create!(
      channel_type: "email",
      enabled: true,
      config: { recipients: ["team@example.com"] }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).twice

    service.call
  end

  test "does nothing when no channels are configured" do
    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "converts status symbols to strings" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, :ok, :drift)

    NotificationDelivery.expects(:deliver).once

    service.call
  end
end
