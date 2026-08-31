module Domain
  module Registry
    # Port (interface) for the Customer repository.
    #
    # The domain declares *what* it needs from persistence; Infrastructure
    # decides *how* (see Infrastructure::Persistence::Repositories::
    # CustomersInActiveRecord). This inversion is what lets the domain be tested
    # without a database, and lets ActiveRecord be replaced without touching a
    # single business rule.
    class CustomerRepository
      def save(customer)      = not_implemented
      def find(id)            = not_implemented
      def find_by_tax_id(tax_id) = not_implemented
      def list(page:, per_page:, query: nil) = not_implemented
      def delete(id)          = not_implemented

      private

      def not_implemented
        raise NotImplementedError, "#{self.class} does not implement this repository method"
      end
    end
  end
end
