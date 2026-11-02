module Application
  module Registry
    # Use case: remove a customer who no longer has anything on the books.
    #
    # Refused (Errors::InUse) while vehicles are attached. Removing something
    # that is already gone succeeds, so the DELETE stays idempotent.
    class RemoveCustomer < Application::Shared::UseCase
      def initialize(customers:)
        @customers = customers
      end

      private

      attr_reader :customers

      def perform(id:) = customers.delete(id)
    end
  end
end
