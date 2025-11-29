class ApiToken < ApplicationRecord
  has_secure_token :token

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  def self.authenticate(token)
    find_by(token: token)
  end
end
