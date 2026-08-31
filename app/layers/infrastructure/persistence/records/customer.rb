module Infrastructure
  module Persistence
    module Records
      class Customer < BaseRecord
        self.table_name = "customers"

        has_many :vehicles, class_name: "Infrastructure::Persistence::Records::Vehicle",
                            foreign_key: :customer_id, dependent: :restrict_with_error,
                            inverse_of: :customer
      end
    end
  end
end
