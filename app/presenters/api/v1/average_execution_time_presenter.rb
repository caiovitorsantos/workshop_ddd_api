module Api
  module V1
    # Output adapter for the average-execution-time indicator.
    module AverageExecutionTimePresenter
      module_function

      def call(since:, delivered_orders:, average_seconds:)
        {
          since: since,
          delivered_orders: delivered_orders,
          average_execution_seconds: average_seconds&.round,
          average_execution_human: humanize(average_seconds)
        }
      end

      # "4h 30min" reads better than 16200 in a dashboard. The raw seconds go
      # out alongside it, so a consumer that wants to do arithmetic still can.
      def humanize(seconds)
        return nil if seconds.nil?

        total_minutes = (seconds / 60).round
        hours, minutes = total_minutes.divmod(60)

        hours.zero? ? "#{minutes}min" : "#{hours}h #{minutes}min"
      end
    end
  end
end
