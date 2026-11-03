module Api
  module V1
    # Administrative indicators — "monitoramento do tempo médio de execução dos
    # serviços".
    #
    # These are **read models**, not aggregate operations: they span many orders
    # and belong to none of them. Computed in SQL rather than by loading
    # aggregates and averaging in Ruby — the answer is one number, and pulling a
    # year of orders into memory to produce it would be absurd.
    class IndicatorsController < BaseController
      def average_execution_time
        since = parse_since
        return render_error("since must be an ISO 8601 date", :bad_request) if since == :invalid

        render json: AverageExecutionTimePresenter.call(
          since: since,
          delivered_orders: repository.delivered_count(since: since),
          average_seconds: repository.average_execution_time(since: since)
        )
      end

      private

      def repository = container.orders

      def parse_since
        return nil if params[:since].blank?

        Time.zone.parse(params[:since]) || :invalid
      rescue ArgumentError
        :invalid
      end
    end
  end
end
