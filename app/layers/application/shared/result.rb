module Application
  module Shared
    # The standard return value of every use case.
    #
    # The Application layer does not raise on *expected* business failure — it
    # returns a Result. Exceptions are reserved for what is genuinely
    # exceptional. That keeps controllers down to `if result.success?` instead
    # of a stack of rescues, and keeps use cases testable without HTTP.
    class Result
      attr_reader :value, :error, :code

      def self.ok(value = nil) = new(success: true, value: value)

      # `code` is a domain-level symbol (:not_found, :invalid_value, ...) that
      # the interface layer maps to an HTTP status.
      def self.failure(error, code: :business_rule_violation)
        new(success: false, error: error, code: code)
      end

      # Converts a domain error into a Result, preserving why it failed.
      def self.from_error(exception)
        code = case exception
        when Domain::Shared::Errors::NotFound          then :not_found
        when Domain::Shared::Errors::InvalidValue      then :invalid_value
        when Domain::Shared::Errors::InvalidTransition then :invalid_transition
        when Domain::Shared::Errors::AlreadyExists     then :already_exists
        else :business_rule_violation
        end

        failure(exception.message, code: code)
      end

      def initialize(success:, value: nil, error: nil, code: nil)
        @success = success
        @value   = value
        @error   = error
        @code    = code
        freeze
      end

      def success? = @success
      def failure? = !@success
    end
  end
end
