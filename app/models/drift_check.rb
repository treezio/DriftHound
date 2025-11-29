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
  after_create :enforce_retention_limit
  def assign_execution_number
    last_number = environment.drift_checks.maximum(:execution_number) || 0
    self.execution_number = last_number + 1
  end

  # Delegate project access for convenience
  delegate :project, to: :environment

  private

  def update_environment_status
    environment.update!(status: status, last_checked_at: created_at)
  end

  def enforce_retention_limit
    excess_checks = environment.drift_checks.order(created_at: :desc).offset(10)
    excess_checks.destroy_all if excess_checks.any?
  end
end
