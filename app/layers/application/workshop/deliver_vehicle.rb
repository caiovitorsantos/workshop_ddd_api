module Application
  module Workshop
    # Use case: the customer took the car.
    #
    # **Pivotal event 4**: the operation closes and the order becomes history —
    # the raw material of the average execution time indicator.
    class DeliverVehicle < ServiceOrderCommand
      private

      def apply(order) = order.deliver!
    end
  end
end
