module Infrastructure
  module Persistence
    module Records
      class ServiceOrder < BaseRecord
        self.table_name = "service_orders"

        has_many :service_items, class_name: "Infrastructure::Persistence::Records::ServiceItem",
                                 foreign_key: :service_order_id, dependent: :destroy,
                                 inverse_of: :service_order
        has_many :part_items, class_name: "Infrastructure::Persistence::Records::PartItem",
                              foreign_key: :service_order_id, dependent: :destroy,
                              inverse_of: :service_order
      end
    end
  end
end
