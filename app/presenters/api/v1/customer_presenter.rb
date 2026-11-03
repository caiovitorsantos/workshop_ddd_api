module Api
  module V1
    # Output adapter: how the API shows a Domain::Registry::Customer.
    #
    # Presenters are the outgoing half of the interface layer. A use case
    # returns domain objects; turning them into JSON is a decision about the
    # HTTP contract, so it lives here, once, instead of in every controller
    # action that happens to return a customer.
    module CustomerPresenter
      def self.call(customer)
        {
          id: customer.id,
          tax_id: customer.tax_id.formatted,
          tax_id_kind: customer.tax_id.kind,
          name: customer.name,
          email: customer.email,
          phone: customer.phone
        }
      end
    end
  end
end
