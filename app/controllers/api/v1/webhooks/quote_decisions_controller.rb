module Api
  module V1
    module Webhooks
      # The customer's decision on a quote, pushed by the external system that
      # shows them the quote.
      #
      # No user JWT — the caller is a system, not a person. It authenticates by
      # signing the raw body with HMAC-SHA256 under QUOTE_WEBHOOK_SECRET (a K8s
      # Secret in the cluster) and sending the hex digest in X-Signature. The
      # comparison is constant-time, and with no secret configured every
      # request is refused: a missing secret must never mean "anyone may sign".
      class QuoteDecisionsController < BaseController
        skip_authentication only: :create

        # Dedicated store, for the reasons given in TrackingController.
        RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 1.megabyte)
        rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE, only: :create

        before_action :verify_signature

        def create
          # Only the signed bytes: `params` would also merge the query string,
          # which the signature does not cover.
          signed = ActionController::Parameters.new(request.request_parameters)

          result = container.decide_quote.call(
            order_number: signed.require(:order_number),
            decision: signed.require(:decision),
            reason: signed[:reason]
          )

          respond_with(result, with: ServiceOrderPresenter.method(:status))
        end

        private

        def verify_signature
          secret = ENV["QUOTE_WEBHOOK_SECRET"].to_s
          expected = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)

          return if secret.present? &&
                    ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["X-Signature"].to_s)

          render_error("invalid signature", :unauthorized)
        end
      end
    end
  end
end
