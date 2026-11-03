module Application
  module Catalog
    # Use case: add a service to what the workshop offers.
    class RegisterService < Application::Shared::UseCase
      def initialize(services:)
        @services = services
      end

      private

      attr_reader :services

      # A duplicate name comes back from the repository as AlreadyExists: the
      # unique index decides, and the adapter translates its answer.
      def perform(name:, price:, description: nil, estimated_minutes: nil)
        services.save(
          Domain::Catalog::Service.new(
            name: name,
            price: Domain::Shared::Money.from_amount(price),
            description: description,
            estimated_minutes: estimated_minutes
          )
        )
      end
    end
  end
end
