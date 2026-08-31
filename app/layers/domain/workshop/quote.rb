module Domain
  module Workshop
    # Quote value object: the snapshot of what the service order will cost, as
    # of the moment it was sent to the customer.
    #
    # It is immutable on purpose. "Quote generated automatically from services
    # and parts" does not mean recomputing on every read: it means the order
    # produces a *new* Quote whenever its set of items changes, so that what the
    # customer approves is exactly the object the customer received.
    class Quote < Domain::Shared::ValueObject
      Errors = Domain::Shared::Errors

      attributes :labour_total, :parts_total, :generated_at

      # Builds the quote from the aggregate's items.
      def self.from_items(service_items:, part_items:, clock: Time)
        new(
          labour_total: sum_of(service_items),
          parts_total: sum_of(part_items),
          generated_at: clock.current
        )
      end

      def self.sum_of(items)
        items.reduce(Domain::Shared::Money.zero) { |acc, item| acc + item.total }
      end
      private_class_method :sum_of

      def total
        labour_total + parts_total
      end

      def empty?
        total.zero?
      end

      private

      def validate!
        raise Errors::InvalidValue, "quote is missing the labour total" if labour_total.nil?
        raise Errors::InvalidValue, "quote is missing the parts total"  if parts_total.nil?
        raise Errors::InvalidValue, "quote is missing its generation time" if generated_at.nil?
      end
    end
  end
end
