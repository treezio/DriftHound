class Invite < ApplicationRecord
  EXPIRATION_DAYS = 3

  belongs_to :created_by, class_name: "User"

  enum :role, { viewer: 0, editor: 1, admin: 2 }

  validates :token, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
  validates :expires_at, presence: true
  validate :email_not_already_registered, on: :create

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :available, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def available?
    used_at.nil? && expires_at > Time.current
  end

  def used?
    used_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def mark_as_used!
    update!(used_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_DAYS.days.from_now
  end

  def email_not_already_registered
    return if email.blank?

    if User.exists?(email: email.downcase)
      errors.add(:email, "is already registered")
    end
  end
end
