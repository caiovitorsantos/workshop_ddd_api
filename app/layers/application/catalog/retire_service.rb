module Application
  module Catalog
    # Use case: stop offering a service without erasing it.
    #
    # Retiring keeps every past order readable; deleting would not. A retired
    # service can no longer be added to an order.
    class RetireService < Application::Shared::UseCase
      def initialize(services:)
        @services = services
      end

      private

      attr_reader :services

      def perform(id:)
        service = services.find(id)
        raise Domain::Shared::Errors::NotFound, "service #{id} not found" if service.nil?

        services.save(service.retire)
      end
    end
  end
end
