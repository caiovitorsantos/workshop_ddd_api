module Domain
  module Registry
    # TaxId value object: the Brazilian CPF (individual) or CNPJ (company) that
    # identifies a Customer at the workshop. It is the customer's natural
    # identity — the front desk looks a customer up by tax id, never by an
    # internal database id.
    #
    # Phase 1 security requirement: "validation of sensitive data (CPF/CNPJ)".
    # The validation lives here, in the domain, and not in a controller, so that
    # a Customer with an invalid tax id cannot exist even in memory.
    class TaxId < Domain::Shared::ValueObject
      Errors = Domain::Shared::Errors

      CPF_LENGTH  = 11
      CNPJ_LENGTH = 14

      attributes :number

      # Accepts formatted ("123.456.789-09") or raw ("12345678909") input.
      def self.parse(input)
        new(number: input.to_s.gsub(/\D/, ""))
      end

      def cpf?  = number.length == CPF_LENGTH
      def cnpj? = number.length == CNPJ_LENGTH
      def kind  = cpf? ? :cpf : :cnpj

      def formatted
        if cpf?
          number.sub(/\A(\d{3})(\d{3})(\d{3})(\d{2})\z/, '\1.\2.\3-\4')
        else
          number.sub(/\A(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})\z/, '\1.\2.\3/\4-\5')
        end
      end

      # For logs and error messages: identifies the record without leaking the
      # whole document.
      def masked
        "#{'*' * (number.length - 4)}#{number[-4..]}"
      end

      def to_s = number

      private

      def validate!
        raise Errors::InvalidValue, "tax id is required" if number.blank?

        case number.length
        when CPF_LENGTH  then validate_cpf!
        when CNPJ_LENGTH then validate_cnpj!
        else
          raise Errors::InvalidValue, "tax id must have 11 (CPF) or 14 (CNPJ) digits"
        end
      end

      def validate_cpf!
        reject_repeated_digits!("CPF")

        digits = number.chars.map(&:to_i)
        first  = cpf_check_digit(digits.first(9), 10)
        second = cpf_check_digit(digits.first(9) + [ first ], 11)

        return if digits[9] == first && digits[10] == second

        raise Errors::InvalidValue, "invalid CPF"
      end

      def validate_cnpj!
        reject_repeated_digits!("CNPJ")

        digits = number.chars.map(&:to_i)
        first  = cnpj_check_digit(digits.first(12))
        second = cnpj_check_digit(digits.first(12) + [ first ])

        return if digits[12] == first && digits[13] == second

        raise Errors::InvalidValue, "invalid CNPJ"
      end

      # 00000000000 and 11111111111 pass the checksum but are not real documents.
      def reject_repeated_digits!(label)
        return unless number.chars.uniq.size == 1

        raise Errors::InvalidValue, "invalid #{label}"
      end

      # Modulo 11 with descending weights, used by the CPF.
      def cpf_check_digit(digits, starting_weight)
        sum = digits.each_with_index.sum { |digit, i| digit * (starting_weight - i) }
        remainder = (sum * 10) % 11
        remainder == 10 ? 0 : remainder
      end

      # Modulo 11 with cyclic weights 2..9, used by the CNPJ.
      def cnpj_check_digit(digits)
        weights = (2..9).cycle.first(digits.size).reverse
        sum = digits.each_with_index.sum { |digit, i| digit * weights[i] }
        remainder = sum % 11
        remainder < 2 ? 0 : 11 - remainder
      end
    end
  end
end
