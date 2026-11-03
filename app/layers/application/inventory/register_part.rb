module Application
  module Inventory
    # Use case: add a part or consumable to the inventory.
    class RegisterPart < Application::Shared::UseCase
      def initialize(parts:)
        @parts = parts
      end

      private

      attr_reader :parts

      # A duplicate SKU comes back from the repository as AlreadyExists.
      def perform(sku:, description:, unit_price:, quantity_on_hand: 0, minimum_stock: 0)
        parts.save(
          Domain::Inventory::Part.new(
            sku: sku,
            description: description,
            unit_price: Domain::Shared::Money.from_amount(unit_price),
            quantity_on_hand: quantity_on_hand,
            minimum_stock: minimum_stock
          )
        )
      end
    end
  end
end
