class Project < ApplicationRecord
  has_many :environments, dependent: :destroy
  has_many :drift_checks, through: :environments

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/i, message: "only allows alphanumeric characters, dashes, and underscores" }

  def self.find_or_create_by_key(key)
    find_or_create_by(key: key) do |project|
      project.name = key.titleize
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
end
