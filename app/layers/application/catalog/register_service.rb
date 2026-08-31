module Application
  module Catalog
    # Use case: add a service to what the workshop offers.
    class RegisterService < Application::Shared::UseCase
      def initialize(services:, name:, price:, description: nil, estimated_minutes: nil)
        @services = services
        @name = name
        @price = price
        @description = description
        @estimated_minutes = estimated_minutes
      end

      private

      attr_reader :services, :name, :price, :description, :estimated_minutes

      def perform
        services.save(
          Domain::Catalog::Service.new(
            name: name,
            price: Domain::Shared::Money.from_amount(price),
            description: description,
            estimated_minutes: estimated_minutes
          )
        )
      rescue ActiveRecord::RecordNotUnique
        # The unique index is the real guard against two requests racing to add
        # the same service; a SELECT-then-INSERT check would have a window
        # between the two. Translate the database's answer into the domain's.
        raise Domain::Shared::Errors::AlreadyExists, "service '#{name}' is already in the catalog"
      end
    end
  end
end
