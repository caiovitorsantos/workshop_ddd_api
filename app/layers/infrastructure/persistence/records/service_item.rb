module Infrastructure
  module Persistence
    module Records
      class ServiceItem < BaseRecord
        self.table_name = "service_items"

        belongs_to :service_order,
                   class_name: "Infrastructure::Persistence::Records::ServiceOrder",
                   inverse_of: :service_items
      end
    end
  end
end
