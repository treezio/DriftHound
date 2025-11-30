require "test_helper"

class NotificationChannelTest < ActiveSupport::TestCase
  # Disable parallel execution to avoid fixture conflicts
  parallelize(workers: 1)

  setup do
    @project = projects(:one)
    @environment = environments(:production)
    # Clean up any existing notification channels from previous tests
    @project.notification_channels.destroy_all
    @environment.notification_channels.destroy_all
  end

  test "requires channel_type" do
    channel = NotificationChannel.new(notifiable: @project)
    assert_not channel.valid?
    assert_includes channel.errors[:channel_type], "can't be blank"
  end

  test "requires notifiable" do
    channel = NotificationChannel.new(channel_type: "slack")
    assert_not channel.valid?
    assert_includes channel.errors[:notifiable], "must exist"
  end

  test "channel_type must be unique per notifiable" do
    @project.notification_channels.create!(channel_type: "slack")
    duplicate = @project.notification_channels.new(channel_type: "slack")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:channel_type], "has already been taken"
  end

  test "same channel_type can exist for different notifiables" do
    @project.notification_channels.create!(channel_type: "slack")
    channel = @environment.notification_channels.new(channel_type: "slack")
    assert channel.valid?
  end

  test "same channel_type can exist for project and its environment" do
    @project.notification_channels.create!(channel_type: "slack")
    @environment.notification_channels.create!(channel_type: "slack")

    assert_equal 1, @project.notification_channels.count
    assert_equal 1, @environment.notification_channels.count
  end

  test "enabled defaults to true" do
    channel = @project.notification_channels.create!(channel_type: "slack")
    assert channel.enabled?
  end

  test "config defaults to empty hash" do
    channel = @project.notification_channels.create!(channel_type: "slack")
    assert_equal({}, channel.config)
  end

  test "can store complex config as jsonb" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      config: {
        token: "xoxb-token",
        channel: "#alerts",
        mention_on_error: true,
        users: [ "U123", "U456" ]
      }
    )

    channel.reload
    assert_equal "xoxb-token", channel.config["token"]
    assert_equal "#alerts", channel.config["channel"]
    assert_equal true, channel.config["mention_on_error"]
    assert_equal [ "U123", "U456" ], channel.config["users"]
  end

  test "enabled scope returns only enabled channels" do
    @project.notification_channels.create!(channel_type: "slack", enabled: true)
    @project.notification_channels.create!(channel_type: "email", enabled: false)

    assert_equal 1, @project.notification_channels.enabled.count
    assert_equal "slack", @project.notification_channels.enabled.first.channel_type
  end

  test "for_type scope filters by channel_type" do
    @project.notification_channels.create!(channel_type: "slack")
    @project.notification_channels.create!(channel_type: "email")

    assert_equal 1, @project.notification_channels.for_type("slack").count
    assert_equal "slack", @project.notification_channels.for_type("slack").first.channel_type
  end

  test "can be associated with Project" do
    channel = @project.notification_channels.create!(channel_type: "slack")
    assert_equal @project, channel.notifiable
    assert_equal "Project", channel.notifiable_type
  end

  test "can be associated with Environment" do
    channel = @environment.notification_channels.create!(channel_type: "slack")
    assert_equal @environment, channel.notifiable
    assert_equal "Environment", channel.notifiable_type
  end

  test "destroying project destroys its notification channels" do
    # Create a fresh project to avoid cascading destroys affecting the count
    project = Project.create!(name: "Temp Project", key: "temp-project")
    project.notification_channels.create!(channel_type: "slack")

    assert_difference "NotificationChannel.count", -1 do
      project.destroy
    end
  end

  test "destroying environment destroys its notification channels" do
    @environment.notification_channels.create!(channel_type: "slack")

    assert_difference "NotificationChannel.count", -1 do
      @environment.destroy
    end
  end
end
