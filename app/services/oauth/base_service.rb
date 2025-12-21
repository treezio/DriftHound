module Oauth
  class BaseService
    class OauthError < StandardError; end
    class InvalidStateError < OauthError; end
    class TokenExchangeError < OauthError; end
    class UserInfoError < OauthError; end
    class OrganizationAccessError < OauthError; end

    ROLE_PRIORITY = { admin: 2, editor: 1, viewer: 0 }.freeze

    def self.provider_name
      raise NotImplementedError
    end

    def initialize(code:, state:, session_state:)
      @code = code
      @state = state
      @session_state = session_state
    end

    def authenticate
      validate_state!
      token = exchange_code_for_token
      user_info = fetch_user_info(token)
      role = determine_role(token, user_info)
      find_or_create_user(user_info, role)
    end

    protected

    def validate_state!
      raise InvalidStateError, "Invalid state parameter" unless @state.present? && @state == @session_state
    end

    def exchange_code_for_token
      raise NotImplementedError
    end

    def fetch_user_info(_token)
      raise NotImplementedError
    end

    def determine_role(_token, _user_info)
      raise NotImplementedError
    end

    def find_or_create_user(user_info, role)
      user = User.find_by(provider: self.class.provider_name, uid: user_info[:uid])
      user ||= User.find_by(email: user_info[:email])

      if user
        update_existing_user(user, user_info, role)
      else
        create_new_user(user_info, role)
      end
    end

    private

    def update_existing_user(user, user_info, role)
      attrs = { role: role }
      attrs[:provider] = self.class.provider_name if user.provider.blank?
      attrs[:uid] = user_info[:uid] if user.uid.blank?

      user.update!(attrs)
      user
    end

    def create_new_user(user_info, role)
      User.create!(
        email: user_info[:email],
        provider: self.class.provider_name,
        uid: user_info[:uid],
        role: role
      )
    end

    def highest_role(roles)
      roles.max_by { |role| ROLE_PRIORITY[role] || -1 }
    end
  end
end
