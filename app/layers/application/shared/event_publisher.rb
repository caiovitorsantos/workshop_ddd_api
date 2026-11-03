module Application
  module Shared
    # Port: hand the domain events an operation produced to whoever listens.
    #
    # Aggregates record what happened (`QuoteApproved`, `StockDeducted`, ...)
    # while they execute a command; the use case drains them after the work is
    # saved and passes them here. What happens next — a log line, an e-mail to
    # the customer, a message on a queue — is an adapter's business, and the
    # use case does not know which one it got.
    #
    # Adapters: Infrastructure::Events::LoggingPublisher (log lines) and
    # ActiveJobPublisher (log lines + e-mail to the customer), the one wired.
    class EventPublisher
      # `events` is an Array of Domain::Shared::DomainEvent, possibly empty.
      def publish(events)
        raise NotImplementedError, "#{self.class} does not implement #publish"
      end
    end
  end
end
