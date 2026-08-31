module Domain
  module Registry
    # LicensePlate value object: the Vehicle's natural identity inside the
    # workshop. Accepts both formats that coexist on Brazilian roads:
    #
    #   legacy    ABC1234  (3 letters + 4 digits)
    #   Mercosur  ABC1D23  (3 letters + digit + letter + 2 digits)
    #
    # Phase 1 security requirement: "validation of sensitive data
    # (... vehicle license plate)".
    class LicensePlate < Domain::Shared::ValueObject
      Errors = Domain::Shared::Errors

      LEGACY_PATTERN   = /\A[A-Z]{3}\d{4}\z/
      MERCOSUR_PATTERN = /\A[A-Z]{3}\d[A-Z]\d{2}\z/

      attributes :code

      # Normalizes input: "abc-1d23" and "ABC1D23" are the same plate.
      def self.parse(input)
        new(code: input.to_s.upcase.gsub(/[^A-Z0-9]/, ""))
      end

      def mercosur?
        MERCOSUR_PATTERN.match?(code)
      end

      def formatted
        mercosur? ? code : code.sub(/\A([A-Z]{3})(\d{4})\z/, '\1-\2')
      end

      def to_s = code

      private

      def validate!
        raise Errors::InvalidValue, "license plate is required" if code.blank?

        return if LEGACY_PATTERN.match?(code) || MERCOSUR_PATTERN.match?(code)

        raise Errors::InvalidValue, "license plate must match ABC1234 or ABC1D23"
      end
    end
  end
end
