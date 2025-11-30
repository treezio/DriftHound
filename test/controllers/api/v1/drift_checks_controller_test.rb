require "test_helper"

class Api::V1::DriftChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_token = ApiToken.create!(name: "test-token")
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
  end

  test "returns unauthorized without token" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "ok" },
      as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "returns unauthorized with invalid token" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "ok" },
      headers: { "Authorization" => "Bearer invalid-token" },
      as: :json

    assert_response :unauthorized
  end

  test "creates drift check for new project and environment" do
    assert_difference [ "Project.count", "Environment.count", "DriftCheck.count" ], 1 do
      post api_v1_environment_checks_path("new-infra-project", "production"),
        params: { status: "ok", add_count: 0, change_count: 0, destroy_count: 0 },
        headers: @auth_header,
        as: :json
    end

    assert_response :created

    project = Project.find_by(key: "new-infra-project")
    assert_not_nil project
    assert_equal "New Infra Project", project.name

    environment = project.environments.find_by(key: "production")
    assert_not_nil environment
    assert_equal "Production", environment.name
    assert environment.ok?
  end

  test "creates drift check for existing project with new environment" do
    project = Project.create!(name: "Existing", key: "existing-project")

    assert_no_difference "Project.count" do
      assert_difference [ "Environment.count", "DriftCheck.count" ], 1 do
        post api_v1_environment_checks_path("existing-project", "staging"),
          params: { status: "drift", add_count: 2, change_count: 1, destroy_count: 0 },
          headers: @auth_header,
          as: :json
      end
    end

    assert_response :created
    environment = project.environments.find_by(key: "staging")
    assert environment.drift?
  end

  test "creates drift check for existing environment" do
    project = Project.create!(name: "Existing", key: "existing-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)

    assert_no_difference [ "Project.count", "Environment.count" ] do
      assert_difference "DriftCheck.count", 1 do
        post api_v1_environment_checks_path("existing-project", "production"),
          params: { status: "drift", add_count: 2, change_count: 1, destroy_count: 0 },
          headers: @auth_header,
          as: :json
      end
    end

    assert_response :created
    environment.reload
    assert environment.drift?
  end

  test "returns created check details" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "drift", add_count: 5, change_count: 3, destroy_count: 1 },
      headers: @auth_header,
      as: :json

    assert_response :created

    body = response.parsed_body
    assert_not_nil body["id"]
    assert_equal "my-project", body["project_key"]
    assert_equal "production", body["environment_key"]
    assert_equal "drift", body["status"]
    assert_not_nil body["created_at"]
  end

  test "accepts raw_output" do
    raw = "Plan: 2 to add, 1 to change, 0 to destroy."

    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "drift", raw_output: raw },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal raw, DriftCheck.last.raw_output
  end

  test "accepts all status values" do
    %w[unknown ok drift error].each do |status|
      post api_v1_environment_checks_path("status-test-#{status}", "production"),
        params: { status: status },
        headers: @auth_header,
        as: :json

      assert_response :created
    end
  end

  test "returns unprocessable entity for invalid status" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "invalid" },
      headers: @auth_header,
      as: :json

    assert_response :unprocessable_entity
  end

  test "creates notification channel when provided in request" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    post api_v1_environment_checks_path("my-project", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {
            channel: "#custom-alerts"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "my-project")
    environment = project.environments.find_by(key: "production")
    channel = environment.notification_channels.find_by(channel_type: "slack")

    assert_not_nil channel
    assert channel.enabled?
    assert_equal "#custom-alerts", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]  # Always uses global token

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "updates existing notification channel when provided in request" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    project = Project.create!(name: "Test", key: "test-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)
    environment.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { "channel" => "#old-channel", "token" => "xoxb-global-token" }
    )

    post api_v1_environment_checks_path("test-project", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {
            channel: "#new-channel"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    channel = environment.notification_channels.find_by(channel_type: "slack")

    # Should update channel and always use global token
    assert_equal "#new-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "allows partial notification config updates" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    project = Project.create!(name: "Test", key: "test-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)
    environment.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { "channel" => "#old-channel", "token" => "xoxb-global-token" }
    )

    # Update just the channel
    post api_v1_environment_checks_path("test-project", "production"),
      params: {
        status: "ok",
        notification_channel: {
          channel_type: "slack",
          config: {
            channel: "#updated-channel"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    channel = environment.notification_channels.find_by(channel_type: "slack")

    assert_equal "#updated-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]  # Always uses global token
    assert channel.enabled? # Should remain enabled

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "can disable notification channel via API" do
    project = Project.create!(name: "Test", key: "test-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)
    environment.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { "channel" => "#alerts" }
    )

    post api_v1_environment_checks_path("test-project", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: false
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    channel = environment.notification_channels.find_by(channel_type: "slack")

    assert_not channel.enabled?
    assert_equal "#alerts", channel.config["channel"] # Config preserved
  end

  test "creates drift check successfully even without notification config" do
    # Ensure backwards compatibility - requests without notification_channel still work
    assert_difference "DriftCheck.count", 1 do
      post api_v1_environment_checks_path("simple-project", "production"),
        params: { status: "ok" },
        headers: @auth_header,
        as: :json
    end

    assert_response :created
  end

  test "falls back to global config for missing notification settings" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    # Only provide channel, should fallback to global token
    post api_v1_environment_checks_path("fallback-test", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {
            channel: "#custom-channel"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "fallback-test")
    environment = project.environments.find_by(key: "production")
    channel = environment.notification_channels.find_by(channel_type: "slack")

    # Should use custom channel but global token
    assert_equal "#custom-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "uses all global config when no custom config provided" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    # Send empty config, should use all global defaults
    post api_v1_environment_checks_path("global-defaults", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {}
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "global-defaults")
    environment = project.environments.find_by(key: "production")
    channel = environment.notification_channels.find_by(channel_type: "slack")

    # Should use all global settings
    assert_equal "#global-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]

    # Restore original config
    Rails.application.config.notifications = original_config
  end
end
