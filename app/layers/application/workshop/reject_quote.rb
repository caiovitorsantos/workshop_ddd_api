module Application
  module Workshop
    # Use case: the customer refused the price.
    #
    # The order was holding reserved stock from the moment its parts were added
    # (`AddPartToOrder`); rejecting the quote releases every unit back to the
    # available balance. Deliberately distinct from `CancelServiceOrder`: nobody
    # refused a price there, and a report on sales lost to price must not
    # confuse the two.
    class RejectQuote < ReleasingOrderCommand
      private

      def apply(order) = order.reject_quote!(reason: reason)
    end
  end
end
