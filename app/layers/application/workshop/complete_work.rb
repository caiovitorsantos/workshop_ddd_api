module Application
  module Workshop
    # Use case: the mechanic finished; the car is ready to hand over.
    class CompleteWork < ServiceOrderCommand
      private

      def apply(order) = order.complete!
    end
  end
end
