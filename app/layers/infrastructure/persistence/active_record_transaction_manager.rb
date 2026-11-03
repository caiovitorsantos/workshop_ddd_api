module Infrastructure
  module Persistence
    # Adapter for the Application::Shared::TransactionManager port.
    #
    # Repositories that take row locks (`find_for_update`) rely on this: the
    # lock lives until the transaction opened here commits or rolls back.
    class ActiveRecordTransactionManager < Application::Shared::TransactionManager
      def within(&) = ActiveRecord::Base.transaction(&)
    end
  end
end
