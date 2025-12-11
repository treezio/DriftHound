class DriftCheck < ApplicationRecord
  belongs_to :environment, touch: true

  enum :status, {
    unknown: 0,
    ok: 1,
    drift: 2,
    error: 3
  }

  validates :status, presence: true

  before_create :assign_execution_number
  after_create :update_environment_status
  after_create :trigger_notification
  after_create :enforce_retention_limit

  def assign_execution_number
    last_number = environment.drift_checks.maximum(:execution_number) || 0
    self.execution_number = last_number + 1
  end

  # Delegate project access for convenience
  delegate :project, to: :environment

  def change_summary
    return nil unless drift?
    return "No changes specified" if add_count.nil? && change_count.nil? && destroy_count.nil?

    parts = []
    parts << "#{add_count} to add" if add_count && add_count > 0
    parts << "#{change_count} to change" if change_count && change_count > 0
    parts << "#{destroy_count} to destroy" if destroy_count && destroy_count > 0

    parts.any? ? parts.join(", ") : "No changes"
  end

  private

  def update_environment_status
    old_status = environment.status
    environment.update!(status: status, last_checked_at: created_at)
    @previous_environment_status = old_status
  end

  def trigger_notification
    # Use the status captured before the update, or 'unknown' if this is the first check
    old_status = @previous_environment_status || 'unknown'

    NotificationJob.perform_later(
      environment_id: environment.id,
      old_status: old_status,
      new_status: status
    )
  end

  def enforce_retention_limit
    excess_checks = environment.drift_checks.order(created_at: :desc).offset(10)
    excess_checks.destroy_all if excess_checks.any?
  end
end
