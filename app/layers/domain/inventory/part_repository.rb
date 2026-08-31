module Domain
  module Inventory
    # Port for the Part aggregate repository.
    class PartRepository
      def save(part)          = not_implemented
      def find(id)            = not_implemented
      def find_by_sku(sku)    = not_implemented
      def list(page:, per_page:, below_minimum: false) = not_implemented
      def delete(id)          = not_implemented

      # Loads the part with a write lock held until the surrounding transaction
      # ends. Required when approving a quote: without it, two approvals can
      # both read "5 on hand", both pass `available?(3)`, and both deduct —
      # promising a part that does not exist.
      #
      # It belongs on the port, not hidden in the adapter, because "I need this
      # part locked for the rest of the transaction" is a statement about the
      # domain's consistency needs, not about ActiveRecord.
      def find_for_update(id) = not_implemented

      private

      def not_implemented
        raise NotImplementedError, "#{self.class} does not implement this repository method"
      end
    end
  end
end
