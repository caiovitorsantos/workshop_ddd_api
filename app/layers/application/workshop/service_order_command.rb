module Application
  module Workshop
    # Base for the use cases that command an existing service order.
    #
    # Every one of them has the same skeleton: load the aggregate, tell it to do
    # something, save it. Only the middle step differs. Writing that skeleton out
    # ten times would mean ten places to get the transaction boundary wrong.
    #
    # The subclasses stay as separate named classes rather than one parameterised
    # one, because the *name* is the point: `ApproveQuote` is a business command
    # that appears on the Event Storming board, has its own endpoint and its own
    # authorisation story. Collapsing them into `TransitionOrder.call(:approve)`
    # would save a few lines and lose the ubiquitous language.
    class ServiceOrderCommand < Application::Shared::UseCase
      def initialize(repository:, id:)
        @repository = repository
        @id = id
      end

      private

      attr_reader :repository, :id

      def perform
        order = repository.find(id)
        raise Domain::Shared::Errors::NotFound, "service order #{id} not found" if order.nil?

        apply(order)
        repository.save(order)
      end

      # Subclasses implement this and nothing else.
      def apply(order)
        raise NotImplementedError, "#{self.class} does not implement #apply"
      end
    end
  end
end
