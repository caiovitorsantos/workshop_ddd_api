# Two-phase stock: a part now tracks how much of its physical balance is
# reserved by open service orders but not yet deducted. `reserve!` holds stock
# when a part is added to an order, `consume_reserved!` turns a reservation into
# a deduction on quote approval, `release!` gives it back on rejection or
# cancellation before approval.
#
# `available_quantity` (quantity_on_hand - quantity_reserved) is what a new
# reservation is checked against. The physical balance and the reorder point are
# untouched, so `below_minimum?` and `GET /parts?below_minimum=true` keep their
# meaning.
class AddQuantityReservedToParts < ActiveRecord::Migration[8.1]
  def change
    add_column :parts, :quantity_reserved, :integer, null: false, default: 0

    # A reservation can never be negative, and can never promise more than the
    # shelf physically holds. Every transition preserves both: reserve checks
    # available first, consume drops on_hand and reserved together, release only
    # lowers reserved, restock only raises on_hand.
    add_check_constraint :parts, "quantity_reserved >= 0",
                         name: "quantity_reserved_not_negative"
    add_check_constraint :parts, "quantity_reserved <= quantity_on_hand",
                         name: "reserved_within_on_hand"
  end
end
