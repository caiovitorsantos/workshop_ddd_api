module Application
  module Registry
    # Use case: register a new customer at the workshop.
    #
    # This is the project's reference vertical slice. Every new use case follows
    # the same shape: take raw input, build domain objects (which validate
    # themselves), talk to repositories only through their ports, return a
    # Result.
    class RegisterCustomer < Application::Shared::UseCase
      def initialize(repository:, tax_id:, name:, email: nil, phone: nil)
        @repository = repository
        @tax_id     = tax_id
        @name       = name
        @email      = email
        @phone      = phone
      end

      private

      attr_reader :repository, :tax_id, :name, :email, :phone

      def perform
        # The value object validates the CPF/CNPJ, so an invalid document never
        # reaches the database in the first place.
        document = Domain::Registry::TaxId.parse(tax_id)

        if repository.find_by_tax_id(document)
          raise Domain::Shared::Errors::AlreadyExists,
                "a customer with tax id #{document.formatted} already exists"
        end

        customer = Domain::Registry::Customer.new(
          tax_id: document, name: name, email: email, phone: phone
        )

        repository.save(customer)
      end
    end
  end
end
