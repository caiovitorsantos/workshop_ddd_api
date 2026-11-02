module Application
  module Inventory
    # Use case: delete a part from the inventory.
    class RemovePart < Application::Shared::UseCase
      def initialize(parts:)
        @parts = parts
      end

      private

      attr_reader :parts

      def perform(id:) = parts.delete(id)
    end
  end
end
