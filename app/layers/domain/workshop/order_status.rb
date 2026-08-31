module Domain
  module Workshop
    # Value object carrying the service order's life cycle and the transitions
    # allowed between the states required by the Tech Challenge:
    #
    #   received -> in_diagnosis -> awaiting_approval -+-> in_progress -> completed -> delivered
    #                                                  |
    #                                                  +-> cancelled  (quote rejected)
    #
    # The status is not a loose string in a controller: it is the object that
    # knows whether the next action is legitimate. "Automatic status changes as
    # actions happen in the system" follows from that — the status changes
    # because the aggregate executed a business command, never because someone
    # PATCHed a field.
    class OrderStatus < Domain::Shared::ValueObject
      Errors = Domain::Shared::Errors

      RECEIVED          = :received
      IN_DIAGNOSIS      = :in_diagnosis
      AWAITING_APPROVAL = :awaiting_approval
      IN_PROGRESS       = :in_progress
      COMPLETED         = :completed
      DELIVERED         = :delivered
      CANCELLED         = :cancelled

      ALL = [
        RECEIVED, IN_DIAGNOSIS, AWAITING_APPROVAL,
        IN_PROGRESS, COMPLETED, DELIVERED, CANCELLED
      ].freeze

      TRANSITIONS = {
        RECEIVED          => [ IN_DIAGNOSIS, CANCELLED ],
        IN_DIAGNOSIS      => [ AWAITING_APPROVAL, CANCELLED ],
        AWAITING_APPROVAL => [ IN_PROGRESS, CANCELLED ],
        IN_PROGRESS       => [ COMPLETED ],
        COMPLETED         => [ DELIVERED ],
        DELIVERED         => [],
        CANCELLED         => []
      }.freeze

      # Labels in Portuguese: this is what the workshop staff reads on screen,
      # and the ubiquitous language of the business is Portuguese even though
      # the code is written in English.
      LABELS = {
        RECEIVED          => "Recebida",
        IN_DIAGNOSIS      => "Em diagnóstico",
        AWAITING_APPROVAL => "Aguardando aprovação",
        IN_PROGRESS       => "Em execução",
        COMPLETED         => "Finalizada",
        DELIVERED         => "Entregue",
        CANCELLED         => "Cancelada"
      }.freeze

      attributes :value

      def self.initial = new(value: RECEIVED)

      def self.parse(input)
        new(value: input.to_s.to_sym)
      end

      # Returns the next status or raises — it never yields an invalid status.
      def transition_to(target)
        target = target.to_sym

        unless TRANSITIONS.fetch(value).include?(target)
          raise Errors::InvalidTransition,
                "cannot move service order from '#{label}' to '#{LABELS.fetch(target, target)}'"
        end

        self.class.new(value: target)
      end

      def can_transition_to?(target)
        TRANSITIONS.fetch(value).include?(target.to_sym)
      end

      def closed?
        value == DELIVERED || value == CANCELLED
      end

      # Is the order still open for adding services and parts?
      def draft?
        value == RECEIVED || value == IN_DIAGNOSIS
      end

      def label  = LABELS.fetch(value)
      def to_s   = value.to_s
      def to_sym = value

      ALL.each do |state|
        define_method(:"#{state}?") { value == state }
      end

      private

      def validate!
        return if ALL.include?(value)

        raise Errors::InvalidValue, "unknown service order status: #{value.inspect}"
      end
    end
  end
end
