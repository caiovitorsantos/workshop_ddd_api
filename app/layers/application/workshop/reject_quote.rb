module Application
  module Workshop
    # Use case: the customer refused the price.
    #
    # No stock to return: parts only leave the shelf on approval, so a rejected
    # quote never touched inventory.
    class RejectQuote < ServiceOrderCommand
      def initialize(repository:, id:, reason: nil)
        super(repository: repository, id: id)
        @reason = reason
      end

      private

      attr_reader :reason

      def apply(order) = order.reject_quote!(reason: reason)
    end
  end
end
