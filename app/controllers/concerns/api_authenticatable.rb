module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
  end

  private

  def authenticate_api_token!
    token = extract_token_from_header
    @current_api_token = ApiToken.authenticate(token)

    unless @current_api_token
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def current_api_token
    @current_api_token
  end
end
