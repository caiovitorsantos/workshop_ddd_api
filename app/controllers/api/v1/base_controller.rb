module Api
  module V1
    # Base of the User Interface layer.
    #
    # Single responsibility: translate HTTP <-> use case. No business rule lives
    # in a controller. If you feel the urge to write a business `if` here, it
    # belongs in an aggregate.
    class BaseController < ApplicationController
      include Authenticatable

      # Domain failure codes -> HTTP statuses. This mapping lives here and
      # nowhere else, which is what keeps HTTP out of the domain.
      STATUS_FOR_CODE = {
        not_found: :not_found,
        invalid_value: :unprocessable_entity,
        invalid_transition: :conflict,
        already_exists: :conflict,
        business_rule_violation: :unprocessable_entity
      }.freeze

      rescue_from ActionController::ParameterMissing do |e|
        render_error("missing required parameter: #{e.param}", :bad_request)
      end

      private

      # The single exit point for use case results.
      def respond_with(result, success: :ok, &serializer)
        if result.success?
          body = serializer ? serializer.call(result.value) : result.value
          render json: body, status: success
        else
          render_error(result.error, STATUS_FOR_CODE.fetch(result.code, :unprocessable_entity))
        end
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end

      def page     = params.fetch(:page, 1).to_i
      def per_page = params.fetch(:per_page, 25).to_i
    end
  end
end
