class Environment < ApplicationRecord
  belongs_to :project
  has_many :drift_checks, dependent: :destroy
  has_many :notification_states, dependent: :destroy
  has_many :notification_channels, as: :notifiable, dependent: :destroy

  # Returns the status of the most recent drift check, or 'unknown' if none
  def last_check_status
    drift_checks.order(created_at: :desc).limit(1).pluck(:status).first || "unknown"
  end

  enum :status, {
    unknown: 0,
    ok: 1,
    drift: 2,
    error: 3
  }

  validates :name, presence: true
  validates :key, presence: true,
                  uniqueness: { scope: :project_id },
                  format: { with: /\A[a-z0-9_-]+\z/i, message: "only allows alphanumeric characters, dashes, and underscores" }

  # Trigger notifications when status changes
  after_update :notify_status_change, if: :saved_change_to_status?

  private

  def notify_status_change
    old_status = status_before_last_save
    new_status = status

    NotificationJob.perform_later(
      environment_id: id,
      old_status: old_status,
      new_status: new_status
    )
  end

  def self.find_or_create_by_key(project, key)
    project.environments.find_or_create_by(key: key) do |environment|
      environment.name = key.titleize
    end
  end
end
