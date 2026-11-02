module Application
  module Catalog
    # Use case: delete a service from the catalog.
    #
    # Order lines carry their own copy of the name and price, so past orders
    # stay readable either way — but a service with history is normally
    # retired (RetireService), which keeps it listable, rather than deleted.
    class RemoveService < Application::Shared::UseCase
      def initialize(services:)
        @services = services
      end

      private

      attr_reader :services

      def perform(id:) = services.delete(id)
    end
  end
end
