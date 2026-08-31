module Domain
  module Shared
    # Money value object, stored in cents so we never add floats.
    #
    # Every monetary amount in the domain (service price, part price, quote
    # total) is a Money — the API never passes a bare BigDecimal around, which
    # is what keeps rounding errors out of an approved quote.
    class Money < ValueObject
      attributes :cents

      def self.from_amount(value)
        raise Errors::InvalidValue, "monetary amount is missing" if value.nil?

        new(cents: (BigDecimal(value.to_s) * 100).round)
      end

      def self.zero
        new(cents: 0)
      end

      def +(other)
        self.class.new(cents: cents + other.cents)
      end

      def *(quantity)
        self.class.new(cents: (cents * quantity).round)
      end

      def amount
        BigDecimal(cents) / 100
      end

      def zero?
        cents.zero?
      end

      def to_s
        format("R$ %.2f", amount)
      end

      private

      def validate!
        raise Errors::InvalidValue, "monetary amount is missing" if cents.nil?
        raise Errors::InvalidValue, "monetary amount cannot be negative" if cents.negative?
      end
    end
  end
end
