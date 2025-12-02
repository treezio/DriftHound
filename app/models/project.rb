class Project < ApplicationRecord
  has_many :environments, dependent: :destroy
  has_many :drift_checks, through: :environments
  has_many :notification_channels, as: :notifiable, dependent: :destroy

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/i, message: "only allows alphanumeric characters, dashes, and underscores" }

  after_create :setup_default_notification_channels

  def self.find_or_create_by_key(key)
    find_or_create_by(key: key) do |project|
      project.name = key
    end
  end

  # Returns the worst status among all environments
  def aggregated_status
    return "unknown" if environments.empty?

    statuses = environments.pluck(:status)
    return "error" if statuses.include?("error")
    return "drift" if statuses.include?("drift")
    return "ok" if statuses.all? { |s| s == "ok" }

    "unknown"
  end

  # Returns the most recent check time across all environments
  def last_checked_at
    environments.maximum(:last_checked_at)
  end

  private

  def setup_default_notification_channels
    notification_config = Rails.application.config.notifications

    # Auto-create Slack channel if globally enabled
    if notification_config[:slack][:enabled] && notification_config[:slack][:token].present?
      notification_channels.create!(
        channel_type: "slack",
        enabled: true,
        config: {
          "token" => notification_config[:slack][:token],
          "channel" => notification_config[:slack][:default_channel]
        }
      )
    end
  end
end
