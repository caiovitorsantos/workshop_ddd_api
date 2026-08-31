module Application
  module Inventory
    # Use case: goods received from a supplier.
    #
    # The only way stock goes *up*, just as approving a quote is the only way it
    # goes down. Neither is an edit to a number: both are movements the
    # aggregate records and publishes an event for.
    class RestockPart < Application::Shared::UseCase
      def initialize(parts:, id:, quantity:)
        @parts = parts
        @id = id
        @quantity = quantity
      end

      private

      attr_reader :parts, :id, :quantity

      def perform
        # Locked for the same reason approval locks: a restock landing between
        # another transaction's read and write would be lost.
        ActiveRecord::Base.transaction do
          part = parts.find_for_update(id)
          raise Domain::Shared::Errors::NotFound, "part #{id} not found" if part.nil?

          parts.save(part.restock!(quantity))
        end
      end
    end
  end
end
