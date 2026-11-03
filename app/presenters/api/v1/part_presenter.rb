module Api
  module V1
    # Output adapter: how the API shows a Domain::Inventory::Part.
    #
    # Shows all three stock figures — on hand, reserved for open orders, and
    # what is left to promise — because the difference between them is the
    # whole two-phase stock flow.
    module PartPresenter
      def self.call(part)
        {
          id: part.id,
          sku: part.sku,
          description: part.description,
          unit_price: part.unit_price.amount.to_s("F"),
          quantity_on_hand: part.quantity_on_hand,
          quantity_reserved: part.quantity_reserved,
          available: part.available_quantity,
          minimum_stock: part.minimum_stock,
          below_minimum: part.below_minimum?
        }
      end
    end
  end
end
