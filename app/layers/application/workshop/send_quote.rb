module Application
  module Workshop
    # Use case: close the diagnosis and put the quote in front of the customer.
    #
    # **Pivotal event 2**: from here the order waits on a decision the workshop
    # does not control.
    class SendQuote < ServiceOrderCommand
      def initialize(repository:, id:, diagnosis:)
        super(repository: repository, id: id)
        @diagnosis = diagnosis
      end

      private

      attr_reader :diagnosis

      def apply(order) = order.send_quote!(diagnosis: diagnosis)
    end
  end
end
