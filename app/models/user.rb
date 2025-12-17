class User < ApplicationRecord
  has_secure_password

  enum :role, { viewer: 0, editor: 1, admin: 2 }

  COMMON_PASSWORDS = %w[
    password password1 password123
    12345678 123456789 1234567890
    qwerty123 qwertyuiop
    letmein1 welcome1 admin123
    changeme iloveyou sunshine
  ].freeze

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :role, presence: true
  validate :password_complexity, if: -> { password.present? }
  validate :password_not_email, if: -> { password.present? }
  validate :password_not_common, if: -> { password.present? }

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
