module Application
  module Inventory
    # Use case: change a part's description, price or reorder point.
    #
    # Stock levels are deliberately out of reach: `quantity_on_hand` moves only
    # through RestockPart and quote approval, `quantity_reserved` only through
    # the service order commands. Both are movements, never edits.
    class RevisePart < Application::Shared::UseCase
      def initialize(parts:)
        @parts = parts
      end

      private

      attr_reader :parts

      # `changes` holds only the attributes the caller sent. The unit price
      # arrives as a plain amount and becomes Money here.
      def perform(id:, **changes)
        part = parts.find(id)
        raise Domain::Shared::Errors::NotFound, "part #{id} not found" if part.nil?

        if changes.key?(:unit_price)
          changes[:unit_price] = Domain::Shared::Money.from_amount(changes[:unit_price])
        end

        parts.save(part.revise(**changes))
      end
    end
  end
end
