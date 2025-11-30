require "test_helper"
require_relative "../../app/notifiers/slack"

class Notifiers::SlackTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production")
    @environment.drift_checks.create!(status: :drift, add_count: 2, change_count: 1)

    @notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    @state = @environment.notification_states.create!(channel: "slack")

    @config = {
      "token" => "xoxb-test-token",
      "channel" => "#infrastructure-alerts"
    }
  end

  test "deliver posts message to Slack with blocks" do
    mock_client = mock
    mock_response = { "ts" => "1234567890.123456", "channel" => "C12345678" }

    ::Slack::Web::Client.expects(:new).with(token: "xoxb-test-token").returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      args[:channel] == "#infrastructure-alerts" &&
      args[:attachments].is_a?(Array) &&
      args[:attachments].first[:blocks].is_a?(Array) &&
      args[:attachments].first[:blocks].first[:type] == "header" &&
      args[:attachments].first[:fallback] == "🟡 Drift Detected"
    end.returns(mock_response)

    Notifiers::Slack.deliver(@notification, @config, @state)

    @state.reload
    assert_equal "1234567890.123456", @state.external_id
    assert_equal Environment.statuses["drift"], @state.last_notified_status
  end

  test "deliver includes project and environment in blocks" do
    mock_client = mock
    mock_response = { "ts" => "1234567890.123456" }

    ::Slack::Web::Client.expects(:new).returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      blocks = args[:attachments].first[:blocks]
      section_text = blocks[1][:text][:text]
      section_text.include?("Test Project") && section_text.include?("Production")
    end.returns(mock_response)

    Notifiers::Slack.deliver(@notification, @config, @state)
  end

  test "deliver includes changes when present" do
    mock_client = mock
    mock_response = { "ts" => "1234567890.123456" }

    ::Slack::Web::Client.expects(:new).returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      blocks = args[:attachments].first[:blocks]
      blocks.any? { |block| block[:text]&.dig(:text)&.include?("2 to add, 1 to change") }
    end.returns(mock_response)

    Notifiers::Slack.deliver(@notification, @config, @state)
  end

  test "deliver includes view details button" do
    mock_client = mock
    mock_response = { "ts" => "1234567890.123456" }

    ::Slack::Web::Client.expects(:new).returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      blocks = args[:attachments].first[:blocks]
      button_block = blocks.find { |b| b[:type] == "actions" }
      button_block &&
      button_block[:elements].first[:text][:text] == "View in DriftHound" &&
      button_block[:elements].first[:url].include?("/projects/test-project/environments/production")
    end.returns(mock_response)

    Notifiers::Slack.deliver(@notification, @config, @state)
  end

  test "update posts new resolved message" do
    @state.update!(
      external_id: "1234567890.123456",
      external_channel_id: "C12345678",
      metadata: { sent_at: 2.hours.ago.iso8601 }
    )

    resolved_notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    mock_client = mock
    mock_response = { "ts" => "1234567890.999999" }
    ::Slack::Web::Client.expects(:new).with(token: "xoxb-test-token").returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      args[:channel] == "#infrastructure-alerts" &&
      args[:attachments].is_a?(Array) &&
      args[:attachments].first[:color] == "#36A64F" &&
      args[:attachments].first[:blocks].is_a?(Array) &&
      args[:attachments].first[:fallback] == "✅ Drift Resolved"
    end.returns(mock_response)

    Notifiers::Slack.update(@state, resolved_notification, @config)

    @state.reload
    assert_nil @state.external_id
    assert_nil @state.last_notified_status
    assert_not_nil @state.metadata["resolved_at"]
  end

  test "update includes resolution time and duration" do
    @state.update!(
      external_id: "1234567890.123456",
      metadata: { sent_at: 2.hours.ago.iso8601 }
    )

    resolved_notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    mock_client = mock
    mock_response = { "ts" => "1234567890.999999" }
    ::Slack::Web::Client.expects(:new).returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      blocks = args[:attachments].first[:blocks]
      # The resolved section should be blocks[2]
      resolved_text = blocks[2][:text][:text]
      resolved_text.include?("Resolved") && resolved_text.include?("2h 0m")
    end.returns(mock_response)

    Notifiers::Slack.update(@state, resolved_notification, @config)
  end

  test "update uses config channel" do
    @state.update!(external_id: "1234567890.123456")

    resolved_notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    mock_client = mock
    mock_response = { "ts" => "1234567890.999999" }
    ::Slack::Web::Client.expects(:new).returns(mock_client)

    mock_client.expects(:chat_postMessage).with do |args|
      args[:channel] == "#infrastructure-alerts"
    end.returns(mock_response)

    Notifiers::Slack.update(@state, resolved_notification, @config)
  end

  test "build_full_url uses APP_URL from ENV" do
    ENV["APP_URL"] = "https://drifthound.example.com"

    url = Notifiers::Slack.send(:build_full_url, "/projects/test/environments/prod")

    assert_equal "https://drifthound.example.com/projects/test/environments/prod", url
  ensure
    ENV.delete("APP_URL")
  end

  test "build_full_url falls back to localhost" do
    ENV.delete("APP_URL")

    url = Notifiers::Slack.send(:build_full_url, "/projects/test/environments/prod")

    assert_equal "http://localhost:3000/projects/test/environments/prod", url
  end
end
