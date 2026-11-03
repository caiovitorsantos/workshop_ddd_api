module Api
  module V1
    # Output adapter: how the API shows a Domain::Catalog::Service.
    module ServicePresenter
      def self.call(service)
        {
          id: service.id,
          name: service.name,
          description: service.description,
          price: service.price.amount.to_s("F"),
          estimated_minutes: service.estimated_minutes,
          active: service.active?
        }
      end
    end
  end
end
