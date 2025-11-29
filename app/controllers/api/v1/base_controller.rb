module Api
  module V1
    class BaseController < ApplicationController
      include ApiAuthenticatable

      skip_before_action :verify_authenticity_token

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: e.message }, status: :unprocessable_entity
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: "Not found" }, status: :not_found
      end

      rescue_from ArgumentError do |e|
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
