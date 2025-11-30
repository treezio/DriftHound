# Global notification configuration
# Loads configuration from config/notifications.yml
# Configure default notification channels that will be auto-created for new projects

config_file = Rails.root.join("config", "notifications.yml")

if File.exist?(config_file)
  config = YAML.safe_load(ERB.new(File.read(config_file)).result, aliases: true)[Rails.env]

  # Convert string keys to symbols for consistency
  Rails.application.config.notifications = config.deep_symbolize_keys.freeze
else
  # Fallback to ENV vars if config file doesn't exist
  Rails.logger.warn("Notifications config file not found, using ENV vars")
  Rails.application.config.notifications = {
    slack: {
      enabled: ENV["SLACK_NOTIFICATIONS_ENABLED"] == "true",
      token: ENV["SLACK_BOT_TOKEN"],
      default_channel: ENV.fetch("SLACK_DEFAULT_CHANNEL", "#infrastructure-drift")
    }
  }.freeze
end
