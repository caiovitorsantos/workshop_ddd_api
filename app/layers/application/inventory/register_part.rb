module Application
  module Inventory
    # Use case: add a part or consumable to the inventory.
    class RegisterPart < Application::Shared::UseCase
      def initialize(parts:, sku:, description:, unit_price:,
                     quantity_on_hand: 0, minimum_stock: 0)
        @parts = parts
        @sku = sku
        @description = description
        @unit_price = unit_price
        @quantity_on_hand = quantity_on_hand
        @minimum_stock = minimum_stock
      end

      private

      attr_reader :parts, :sku, :description, :unit_price, :quantity_on_hand, :minimum_stock

      def perform
        parts.save(
          Domain::Inventory::Part.new(
            sku: sku,
            description: description,
            unit_price: Domain::Shared::Money.from_amount(unit_price),
            quantity_on_hand: quantity_on_hand,
            minimum_stock: minimum_stock
          )
        )
      rescue ActiveRecord::RecordNotUnique
        raise Domain::Shared::Errors::AlreadyExists, "part '#{sku.to_s.upcase}' already exists"
      end
    end
  end
end
