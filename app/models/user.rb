class User < ApplicationRecord
  has_secure_password validations: false

  enum :role, { viewer: 0, editor: 1, admin: 2 }

  COMMON_PASSWORDS = %w[
    password password1 password123
    12345678 123456789 1234567890
    qwerty123 qwertyuiop
    letmein1 welcome1 admin123
    changeme iloveyou sunshine
  ].freeze

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true
  validates :password, presence: true, if: :password_required?
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :password_complexity, if: -> { password.present? }
  validate :password_not_email, if: -> { password.present? }
  validate :password_not_common, if: -> { password.present? }
  validates :uid, presence: true, if: :oauth_user?
  validates :uid, uniqueness: { scope: :provider }, if: :oauth_user?

  def oauth_user?
    provider.present?
  end

  def password_required?
    !oauth_user? && password_digest.blank?
  end

  def can_use_password?
    password_digest.present?
  end

  def can_edit?
    editor? || admin?
  end

  def can_manage_users?
    admin?
  end

  def can_destroy_resources?
    admin?
  end

  private

  def password_complexity
    return if password.match?(/[a-zA-Z]/) && password.match?(/\d/)

    errors.add(:password, "must include at least one letter and one number")
  end

  def password_not_email
    return if email.blank?
    return unless password.downcase == email.downcase.split("@").first

    errors.add(:password, "cannot be the same as your email")
  end

  def password_not_common
    return unless COMMON_PASSWORDS.include?(password.downcase)

    errors.add(:password, "is too common, please choose a more secure password")
  end
end
