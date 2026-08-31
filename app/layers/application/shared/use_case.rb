module Application
  module Shared
    # Base class for use cases.
    #
    # The Application layer's job is orchestration: fetch aggregates from
    # repositories, tell the aggregate to execute a command, persist the result,
    # report upwards. It does not decide *rules* — that belongs to the Domain.
    # If you find yourself writing a business `if` here, it belongs in an
    # aggregate.
    class UseCase
      def self.call(...) = new(...).call

      def call
        Result.ok(perform)
      rescue Domain::Shared::Errors::Base => e
        Result.from_error(e)
      end

      private

      def perform
        raise NotImplementedError, "#{self.class} does not implement #perform"
      end
    end
  end
end
