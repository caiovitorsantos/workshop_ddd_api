module Application
  module Inventory
    # Use case: goods received from a supplier.
    #
    # The only way stock goes *up*, just as approving a quote is the only way it
    # goes down. Neither is an edit to a number: both are movements the
    # aggregate records and publishes an event for.
    class RestockPart < Application::Shared::UseCase
      def initialize(parts:, transaction:, events:)
        @parts = parts
        @transaction = transaction
        @events = events
      end

      private

      attr_reader :parts, :transaction, :events

      def perform(id:, quantity:)
        # Locked for the same reason approval locks: a restock landing between
        # another transaction's read and write would be lost.
        part, saved = transaction.within do
          part = parts.find_for_update(id)
          raise Domain::Shared::Errors::NotFound, "part #{id} not found" if part.nil?

          [ part, parts.save(part.restock!(quantity)) ]
        end

        publish_events_of(part)
        saved
      end
    end
  end
end
