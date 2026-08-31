module Domain
  module Shared
    # Gives an aggregate root the ability to publish domain events.
    #
    # Events are collected in memory while the aggregate executes its commands.
    # The use case drains them after persisting, and decides the side effect
    # (deduct stock, notify the customer). There is no message bus: the MVP is a
    # monolith, and a broker here would be complexity without a demand — but the
    # aggregates already speak in events, so adding one later changes the
    # Application layer and nothing in the Domain.
    module PublishesEvents
      # Public because factory methods (`ServiceOrder.open`) need to record the
      # creation event from outside the instance. Not part of the business API —
      # callers command, they do not publish.
      def record_event(event_class, **payload)
        recorded_events << event_class.new(
          aggregate_id: id, occurred_at: clock.current, payload: payload
        )
      end

      # Events accumulated since the last read, handed over and forgotten. The
      # aggregate does not keep a history: that is the repository's job.
      def drain_events
        recorded_events.dup.tap { recorded_events.clear }
      end

      private

      def recorded_events
        @recorded_events ||= []
      end

      # Aggregates that take a `clock:` for testability override this by simply
      # setting @clock; the rest get the real one.
      def clock
        @clock || Time
      end
    end
  end
end
