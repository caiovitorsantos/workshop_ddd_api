module Domain
  module Catalog
    # Port for the Service aggregate repository.
    class ServiceRepository
      def save(service) = not_implemented
      def find(id)      = not_implemented
      def list(page:, per_page:, active_only: true) = not_implemented
      def delete(id)    = not_implemented

      private

      def not_implemented
        raise NotImplementedError, "#{self.class} does not implement this repository method"
      end
    end
  end
end
