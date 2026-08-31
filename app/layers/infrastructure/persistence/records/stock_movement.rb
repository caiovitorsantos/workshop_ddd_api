module Infrastructure
  module Persistence
    module Records
      class StockMovement < BaseRecord
        self.table_name = "stock_movements"

        belongs_to :part, class_name: "Infrastructure::Persistence::Records::Part"
      end
    end
  end
end
