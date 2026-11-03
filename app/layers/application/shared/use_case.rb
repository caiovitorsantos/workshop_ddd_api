module Application
  module Shared
    # Base class for use cases.
    #
    # The Application layer's job is orchestration: fetch aggregates from
    # repositories, tell the aggregate to execute a command, persist the result,
    # report upwards. It does not decide *rules* — that belongs to the Domain.
    # If you find yourself writing a business `if` here, it belongs in an
    # aggregate.
    #
    # A use case receives two different things, through two different doors:
    #
    #   * its **dependencies** — the ports it talks to (repositories and the
    #     like) — through the constructor, once, from the composition root
    #     (Infrastructure::Container). The use case never picks an
    #     implementation itself; that is the Dependency Inversion Principle.
    #   * the **input** of one execution through `#call`. The keyword list of
    #     each subclass's `#perform` is that use case's Input Port, and the
    #     Result it returns is its Output Port.
    #
    #   approve = ApproveQuote.new(orders: orders, parts: parts)  # wiring
    #   approve.call(id: 42)                                      # execution
    class UseCase
      def call(**input)
        Result.ok(perform(**input))
      rescue Domain::Shared::Errors::Base => e
        Result.from_error(e)
      end

      private

      def perform(**)
        raise NotImplementedError, "#{self.class} does not implement #perform"
      end

      # Hands what the aggregates recorded to the EventPublisher port (the
      # subclass's `events` dependency). Called only once the work is saved —
      # and, inside a unit of work, once it has committed — so nothing is
      # announced that a rollback then took back.
      def publish_events_of(*aggregates)
        events.publish(aggregates.flat_map(&:drain_events))
      end
    end
  end
end
