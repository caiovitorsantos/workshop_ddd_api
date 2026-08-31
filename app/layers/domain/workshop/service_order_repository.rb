module Domain
  module Workshop
    # Port for the ServiceOrder aggregate repository.
    class ServiceOrderRepository
      def save(order)              = not_implemented
      def find(id)                 = not_implemented
      def find_by_number(number)   = not_implemented
      def next_number              = not_implemented
      def list(page:, per_page:, status: nil, customer_id: nil) = not_implemented

      # Read models behind the "average execution time" indicator. Queries, not
      # aggregate operations: they span many orders and belong to no single one.
      #
      # An average without its sample size is a number nobody can act on — two
      # delivered orders and two hundred deserve different confidence — so the
      # count travels with it.
      def average_execution_time(since: nil) = not_implemented
      def delivered_count(since: nil)        = not_implemented

      private

      def not_implemented
        raise NotImplementedError, "#{self.class} does not implement this repository method"
      end
    end
  end
end
