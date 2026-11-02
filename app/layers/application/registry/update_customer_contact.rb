module Application
  module Registry
    # Use case: correct a customer's name, e-mail or phone.
    #
    # Only the contact details move. The tax id is the customer's natural
    # identity and has no way in: changing it would silently hand a service
    # history to someone else.
    class UpdateCustomerContact < Application::Shared::UseCase
      def initialize(customers:)
        @customers = customers
      end

      private

      attr_reader :customers

      # `changes` holds only the attributes the caller sent (name, email,
      # phone); whatever is absent keeps its current value.
      def perform(id:, **changes)
        customer = customers.find(id)
        raise Domain::Shared::Errors::NotFound, "customer #{id} not found" if customer.nil?

        customers.save(customer.update_contact(**changes))
      end
    end
  end
end
