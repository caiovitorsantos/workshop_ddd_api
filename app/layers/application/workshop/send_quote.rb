module Application
  module Workshop
    # Use case: close the diagnosis and put the quote in front of the customer.
    #
    # **Pivotal event 2**: from here the order waits on a decision the workshop
    # does not control.
    class SendQuote < ServiceOrderCommand
      private

      def apply(order, diagnosis:) = order.send_quote!(diagnosis: diagnosis)
    end
  end
end
