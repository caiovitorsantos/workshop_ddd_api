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

        seconds = repository.average_execution_time(since: since)

        render json: {
          since: since,
          delivered_orders: repository.delivered_count(since: since),
          average_execution_seconds: seconds&.round,
          average_execution_human: humanize(seconds)
        }
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new
      end

      def parse_since
        return nil if params[:since].blank?

        Time.zone.parse(params[:since]) || :invalid
      rescue ArgumentError
        :invalid
      end

      # "4h 30min" reads better than 16200 in a dashboard. The raw seconds go out
      # alongside it, so a consumer that wants to do arithmetic still can.
      def humanize(seconds)
        return nil if seconds.nil?

        total_minutes = (seconds / 60).round
        hours, minutes = total_minutes.divmod(60)

        hours.zero? ? "#{minutes}min" : "#{hours}h #{minutes}min"
      end
    end
  end
end
