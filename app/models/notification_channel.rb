class NotificationChannel < ApplicationRecord
  belongs_to :notifiable, polymorphic: true

  validates :channel_type, presence: true,
            uniqueness: { scope: [ :notifiable_type, :notifiable_id ] }

  scope :enabled, -> { where(enabled: true) }
  scope :for_type, ->(type) { where(channel_type: type) }
end
