require "test_helper"

class ProjectNotificationSetupTest < ActiveSupport::TestCase
  setup do
    # Save original config
    @original_config = Rails.application.config.notifications
  end

  teardown do
    # Restore original config
    Rails.application.config.notifications = @original_config
  end

  test "creates slack notification channel when Slack is globally enabled" do
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-test-token",
        default_channel: "#drift-alerts"
      }
    }

    project = Project.create!(name: "Test Project", key: "test-project")

    assert_equal 1, project.notification_channels.count
    slack_channel = project.notification_channels.first
    assert_equal "slack", slack_channel.channel_type
    assert slack_channel.enabled?
    assert_equal "xoxb-test-token", slack_channel.config["token"]
    assert_equal "#drift-alerts", slack_channel.config["channel"]
  end

  test "does not create slack channel when Slack is disabled" do
    Rails.application.config.notifications = {
      slack: {
        enabled: false,
        token: "xoxb-test-token",
        default_channel: "#drift-alerts"
      }
    }

    project = Project.create!(name: "Test Project", key: "test-project")

    assert_equal 0, project.notification_channels.count
  end

  test "does not create slack channel when token is missing" do
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: nil,
        default_channel: "#drift-alerts"
      }
    }

    project = Project.create!(name: "Test Project", key: "test-project")

    assert_equal 0, project.notification_channels.count
  end

  test "uses default channel from config" do
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-test-token",
        default_channel: "#custom-channel"
      }
    }

    project = Project.create!(name: "Test Project", key: "test-project")

    slack_channel = project.notification_channels.first
    assert_equal "#custom-channel", slack_channel.config["channel"]
  end
end
