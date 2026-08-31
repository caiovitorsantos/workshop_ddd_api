module Infrastructure
  module Persistence
    module Records
      class PartItem < BaseRecord
        self.table_name = "part_items"

        belongs_to :service_order,
                   class_name: "Infrastructure::Persistence::Records::ServiceOrder",
                   inverse_of: :part_items
      end
    end
  end
end
