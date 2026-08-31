module Domain
  module Registry
    # Port for the Vehicle aggregate repository.
    class VehicleRepository
      def save(vehicle)          = not_implemented
      def find(id)               = not_implemented
      def find_by_plate(plate)   = not_implemented
      def list_for_customer(customer_id) = not_implemented
      def delete(id)             = not_implemented

      private

      def not_implemented
        raise NotImplementedError, "#{self.class} does not implement this repository method"
      end
    end
  end
end
