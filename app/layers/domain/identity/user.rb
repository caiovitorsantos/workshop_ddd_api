module Domain
  module Identity
    # User aggregate root: whoever operates the system from the inside (front
    # desk, mechanic, manager). A *generic* subdomain — it does not set the
    # workshop apart in the market, but it is what protects the administrative
    # APIs required by Phase 1.
    #
    # A plaintext password never reaches this class: the aggregate only ever
    # sees the digest produced by Infrastructure (BCrypt).
    class User < Domain::Shared::Entity
      Errors = Domain::Shared::Errors

      ROLES = %i[front_desk mechanic manager].freeze

      attr_reader :name, :email, :role, :password_digest, :active

      def initialize(id: nil, name:, email:, role:, password_digest:, active: true)
        super(id: id)
        @name            = name.to_s.strip
        @email           = email.to_s.strip.downcase
        @role            = role.to_sym
        @password_digest = password_digest
        @active          = active
        validate!
      end

      def manager? = role == :manager
      def active?  = !!active

      # Write access to the administrative APIs. The customer's public order
      # tracking endpoint does not go through here.
      def may_administer? = active? && ROLES.include?(role)

      private

      def validate!
        raise Errors::InvalidValue, "user name is required" if name.blank?
        raise Errors::InvalidValue, "user password is required" if password_digest.blank?
        raise Errors::InvalidValue, "unknown role: #{role}" unless ROLES.include?(role)

        return if email.match?(URI::MailTo::EMAIL_REGEXP)

        raise Errors::InvalidValue, "invalid email"
      end
    end
  end
end
