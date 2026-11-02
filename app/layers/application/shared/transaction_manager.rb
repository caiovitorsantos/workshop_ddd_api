module Application
  module Shared
    # Port: run a block as one atomic unit of work.
    #
    # Some use cases change two aggregates that must move together — an order's
    # status and a part's stock balance. They need "all or nothing", but how a
    # transaction is opened is a detail of the database, so the Application
    # layer only states the need:
    #
    #   transaction.within do
    #     ...  # every repository call in here commits or rolls back together
    #   end
    #
    # An exception raised inside the block rolls the work back and propagates,
    # so a domain error still reaches UseCase#call and becomes a Result.
    #
    # The adapter is Infrastructure::Persistence::ActiveRecordTransactionManager.
    class TransactionManager
      def within
        raise NotImplementedError, "#{self.class} does not implement #within"
      end
    end
  end
end
