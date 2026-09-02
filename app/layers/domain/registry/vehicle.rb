module Domain
  module Registry
    # Vehicle aggregate root. References its owner by `customer_id` — the id of
    # another aggregate, never the Customer object itself. Keeping aggregates
    # small is what guarantees a transaction only ever changes one of them.
    class Vehicle < Domain::Shared::Entity
      Errors = Domain::Shared::Errors

      MINIMUM_YEAR = 1900

      attr_reader :plate, :make, :model, :year, :customer_id

      def initialize(id: nil, plate:, make:, model:, year:, customer_id:)
        super(id: id)
        @plate       = plate
        @make        = make.to_s.strip
        @model       = model.to_s.strip
        @year        = year&.to_i
        @customer_id = customer_id
        validate!
      end

      # Command: fix a typo in the description.
      #
      # The plate is not editable — like a customer's tax id, it is the
      # aggregate's natural identity. A wrong plate is a different vehicle, and
      # correcting it by editing would silently reassign an order history to
      # someone else's car.
      def correct_details(make: self.make, model: self.model, year: self.year)
        self.class.new(
          id: id, plate: plate, make: make, model: model,
          year: year, customer_id: customer_id
        )
      end

      def description
        "#{make} #{model} #{year} (#{plate.formatted})"
      end

      private

      def validate!
        raise Errors::InvalidValue, "vehicle make is required"  if make.blank?
        raise Errors::InvalidValue, "vehicle model is required" if model.blank?
        raise Errors::InvalidValue, "vehicle owner is required" if customer_id.blank?

        # Next year is allowed: dealerships sell model-year cars ahead of time.
        upper_bound = Time.current.year + 1
        return if year&.between?(MINIMUM_YEAR, upper_bound)

        raise Errors::InvalidValue, "year must be between #{MINIMUM_YEAR} and #{upper_bound}"
      end
    end
  end
end
