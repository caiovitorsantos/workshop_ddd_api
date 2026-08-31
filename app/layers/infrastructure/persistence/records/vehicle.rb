module Infrastructure
  module Persistence
    module Records
      class Vehicle < BaseRecord
        self.table_name = "vehicles"

        belongs_to :customer, class_name: "Infrastructure::Persistence::Records::Customer",
                              inverse_of: :vehicles
      end
    end
  end
end
