module Domain
  module Shared
    # The domain's vocabulary of failure. The interface layer maps each error to
    # an HTTP status (see Api::V1::BaseController) — the domain itself never
    # knows what an HTTP status is.
    module Errors
      # Base class, so callers can `rescue Domain::Shared::Errors::Base`.
      class Base < StandardError; end

      # A value reached the domain violating the rule that defines it:
      # an invalid CPF, a malformed license plate, a negative quantity.
      class InvalidValue < Base; end

      # The operation is legitimate, but not in this state of the aggregate —
      # approving the quote of an already delivered service order, for instance.
      class InvalidTransition < Base; end

      # The operation would break an invariant of the aggregate.
      class BusinessRuleViolation < Base; end

      # The requested aggregate does not exist in the repository.
      class NotFound < Base; end

      # An aggregate with this natural identity already exists (tax id, plate, SKU).
      class AlreadyExists < Base; end
    end
  end
end
