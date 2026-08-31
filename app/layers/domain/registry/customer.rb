module Domain
  module Registry
    # Customer aggregate root: whoever drops a vehicle off at the workshop,
    # individual or company.
    #
    # It deliberately does not hold its vehicles. Vehicle is an aggregate of its
    # own, referenced by id, so that a car can change owner without rewriting
    # the customer, and cadastral changes never lock two tables at once.
    class Customer < Domain::Shared::Entity
      Errors = Domain::Shared::Errors

      attr_reader :tax_id, :name, :email, :phone

      def initialize(id: nil, tax_id:, name:, email: nil, phone: nil)
        super(id: id)
        @tax_id = tax_id
        @name   = name.to_s.strip
        @email  = email.presence&.downcase
        @phone  = phone.presence&.gsub(/\D/, "")
        validate!
      end

      # Command: the customer updated their contact details.
      #
      # The tax id is not editable — it is the aggregate's natural identity.
      # A wrong tax id means a different customer, not an edit.
      def update_contact(name: self.name, email: self.email, phone: self.phone)
        self.class.new(id: id, tax_id: tax_id, name: name, email: email, phone: phone)
      end

      def company?
        tax_id.cnpj?
      end

      private

      def validate!
        raise Errors::InvalidValue, "customer name is required" if name.blank?
        raise Errors::InvalidValue, "customer name is too short" if name.length < 2

        return if email.nil? || email.match?(URI::MailTo::EMAIL_REGEXP)

        raise Errors::InvalidValue, "invalid email"
      end
    end
  end
end
