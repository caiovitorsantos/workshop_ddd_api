module Application
  module Workshop
    # Use case: the mechanic took the order and began investigating.
    class StartDiagnosis < ServiceOrderCommand
      private

      def apply(order) = order.start_diagnosis!
    end
  end
end
