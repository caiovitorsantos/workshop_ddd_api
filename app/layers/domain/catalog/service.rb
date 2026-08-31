module Domain
  module Catalog
    # Service aggregate root: what the workshop knows how to do and what it
    # charges for it (oil change, alignment, full inspection...).
    #
    # `estimated_minutes` is what the measured execution time of real orders
    # gets compared against — the basis of the "average service execution time"
    # indicator.
    class Service < Domain::Shared::Entity
      Errors = Domain::Shared::Errors

      attr_reader :name, :description, :price, :estimated_minutes, :active

      def initialize(id: nil, name:, price:, description: nil,
                     estimated_minutes: nil, active: true)
        super(id: id)
        @name              = name.to_s.strip
        @description       = description&.strip
        @price             = price
        @estimated_minutes = estimated_minutes&.to_i
        @active            = active
        validate!
      end

      def active? = !!active

      # Command: revise what the workshop offers and charges.
      #
      # Changing the price here does not disturb any quote already sent: items
      # copy the price into the order when they are added (see
      # Domain::Workshop::ServiceItem), so the catalog and the open orders are
      # deliberately independent.
      def revise(name: self.name, description: self.description, price: self.price,
                 estimated_minutes: self.estimated_minutes, active: self.active)
        self.class.new(
          id: id, name: name, description: description, price: price,
          estimated_minutes: estimated_minutes, active: active
        )
      end

      # Command: stop offering this service without deleting its history.
      def retire = revise(active: false)

      private

      def validate!
        raise Errors::InvalidValue, "service name is required"  if name.blank?
        raise Errors::InvalidValue, "service price is required" if price.nil?

        return if estimated_minutes.nil? || estimated_minutes.positive?

        raise Errors::InvalidValue, "estimated duration must be positive"
      end
    end
  end
end
