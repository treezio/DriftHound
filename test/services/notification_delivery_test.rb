require "test_helper"

class NotificationDeliveryTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
    @environment.drift_checks.create!(status: :drift, add_count: 2, change_count: 1)

    @notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    @channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts", token: "xoxb-test" }
    )
  end

  test "delivers new notification when no previous state exists" do
    mock_adapter = mock
    mock_adapter.expects(:deliver).with(@notification, @channel.config, instance_of(NotificationState))

    NotificationDelivery.stubs(:resolve_adapter).returns(mock_adapter)

    delivery = NotificationDelivery.new(@notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end

  test "updates existing notification when state has external_id and should_update_existing" do
    # Create existing notification state
    @environment.notification_states.create!(
      channel: "slack",
      external_id: "1234567890.123456",
      last_notified_status: Environment.statuses["drift"]
    )

    resolved_notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    mock_adapter = mock
    mock_adapter.expects(:update).with(instance_of(NotificationState), resolved_notification, @channel.config)

    delivery = NotificationDelivery.new(resolved_notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end

  test "delivers new notification even if state exists but no external_id" do
    # Create state without external_id
    @environment.notification_states.create!(
      channel: "slack",
      last_notified_status: nil
    )

    mock_adapter = mock
    mock_adapter.expects(:deliver).with(@notification, @channel.config, instance_of(NotificationState))

    delivery = NotificationDelivery.new(@notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end

  test "creates notification_state if it doesn't exist" do
    assert_difference "NotificationState.count", 1 do
      mock_adapter = mock
      mock_adapter.expects(:deliver)

      delivery = NotificationDelivery.new(@notification, @channel)
      delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
      delivery.deliver
    end

    state = @environment.notification_states.last
    assert_equal "slack", state.channel
  end

  test "reuses existing notification_state" do
    @environment.notification_states.create!(channel: "slack")

    assert_no_difference "NotificationState.count" do
      mock_adapter = mock
      mock_adapter.expects(:deliver)

      delivery = NotificationDelivery.new(@notification, @channel)
      delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
      delivery.deliver
    end
  end

  test "logs error and continues when adapter raises exception" do
    mock_adapter = mock
    mock_adapter.expects(:deliver).raises(StandardError.new("API error"))

    Rails.logger.expects(:error).with(regexp_matches(/Notification delivery failed: API error/))
    Rails.logger.expects(:error).with(regexp_matches(/notification_delivery\.rb/)) # backtrace

    delivery = NotificationDelivery.new(@notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)

    # Should not raise
    delivery.deliver
    assert true # Add assertion
  end

  test "does nothing when adapter class is not found" do
    @channel.update!(channel_type: "unknown")

    # The adapter won't be found, so delivery will return early
    # Should not raise
    assert_nothing_raised do
      NotificationDelivery.deliver(notification: @notification, channel: @channel)
    end
  end

  test "resolves slack adapter" do
    delivery = NotificationDelivery.new(@notification, @channel)
    adapter_class = delivery.send(:resolve_adapter, "slack")

    assert_equal Notifiers::Slack, adapter_class
  end

  test "returns nil for unsupported adapter types" do
    @channel.update!(channel_type: "email")
    delivery = NotificationDelivery.new(@notification, @channel)
    adapter_class = delivery.send(:resolve_adapter, "email")

    # Email is not supported yet, should return nil
    assert_nil adapter_class
  end

  test "returns nil for unknown adapter type" do
    delivery = NotificationDelivery.new(@notification, @channel)
    adapter_class = delivery.send(:resolve_adapter, "unknown")

    assert_nil adapter_class
  end

  test "class method deliver creates instance and calls deliver" do
    mock_adapter = mock
    mock_adapter.expects(:deliver)

    delivery_instance = NotificationDelivery.new(@notification, @channel)
    delivery_instance.send(:instance_variable_set, :@adapter_class, mock_adapter)

    NotificationDelivery.expects(:new).with(@notification, @channel).returns(delivery_instance)

    NotificationDelivery.deliver(notification: @notification, channel: @channel)
  end
end
