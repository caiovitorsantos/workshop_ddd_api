module Infrastructure
  module Events
    # Adapter for Application::Shared::EventPublisher that writes one log line
    # per domain event:
    #
    #   domain_event=quote_approved aggregate_id=42 occurred_at=2026-11-02T20:31:07Z total_cents=21000
    #
    # Key=value so the line can be searched and parsed by whatever collects the
    # logs (the cluster ships stdout). It is also the trail that shows, in the
    # running system, that the events on the Event Storming board really fire.
    class LoggingPublisher < Application::Shared::EventPublisher
      def initialize(logger:)
        @logger = logger
      end

      def publish(events)
        events.each { |event| logger.info(line_for(event)) }
      end

      private

      attr_reader :logger

      def line_for(event)
        fields = {
          domain_event: event.name,
          aggregate_id: event.aggregate_id,
          occurred_at: event.occurred_at&.utc&.iso8601
        }.merge(event.payload)

        fields.map { |key, value| "#{key}=#{value}" }.join(" ")
      end
    end
  end
end
