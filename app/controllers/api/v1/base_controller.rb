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
        in_use: :conflict,
        business_rule_violation: :unprocessable_entity
      }.freeze

      rescue_from ActionController::ParameterMissing do |e|
        render_error("missing required parameter: #{e.param}", :bad_request)
      end

      private

      # Use cases and repositories come assembled from the composition root;
      # a controller never picks an implementation itself.
      def container = @container ||= Infrastructure::Container.new

      # The single exit point for use case results. `with:` names the presenter
      # (app/presenters) that turns the domain object into the HTTP contract.
      def respond_with(result, with: nil, success: :ok)
        if result.failure?
          render_error(result.error, STATUS_FOR_CODE.fetch(result.code, :unprocessable_entity))
        elsif success == :no_content
          head :no_content
        else
          render json: with ? with.call(result.value) : result.value, status: success
        end
      end

      # A read: the record through its presenter, or a 404 naming what is missing.
      def render_found(record, with:, missing:)
        return render_error("#{missing} not found", :not_found) if record.nil?

        render json: with.call(record)
      end

      # A page of a listing, in the envelope every index action shares.
      def render_page(records, total, with:)
        render json: {
          data: records.map { |record| with.call(record) },
          pagination: { page: page, per_page: per_page, total: total }
        }
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end

      # The subset of `permitted` the client actually sent, as keywords for a
      # use case. An absent attribute keeps its current value; naming the
      # editable ones here is what keeps the rest (a plate, a tax id, a stock
      # level) out of reach of a PATCH.
      def changes_from(permitted, *editable)
        permitted.slice(*editable).to_h.symbolize_keys
      end

      def page     = params.fetch(:page, 1).to_i
      def per_page = params.fetch(:per_page, 25).to_i
    end
  end
end
