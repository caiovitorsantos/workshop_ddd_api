module Infrastructure
  # The composition root.
  #
  # The one place in the application that knows which concrete class plays each
  # port, and the one place where use cases are wired to their dependencies.
  # Everything inside the circle — Domain and Application — depends on
  # abstractions; this class is where the abstractions meet the details.
  #
  # Controllers ask it for a use case already assembled and only supply the
  # input of the request:
  #
  #   container.approve_quote.call(id: params[:id])
  #
  # Swapping an adapter (a fake repository in a spec, another database
  # tomorrow) means changing a line here, not hunting through controllers.
  #
  # Repositories are stateless, so building a container per request costs a
  # handful of small objects and keeps requests from sharing anything.
  class Container
    Repositories = Persistence::Repositories

    # --- Ports: repositories ---------------------------------------------------

    def customers = @customers ||= Repositories::CustomersInActiveRecord.new
    def vehicles  = @vehicles  ||= Repositories::VehiclesInActiveRecord.new
    def services  = @services  ||= Repositories::ServicesInActiveRecord.new
    def parts     = @parts     ||= Repositories::PartsInActiveRecord.new
    def orders    = @orders    ||= Repositories::ServiceOrdersInActiveRecord.new
    def users     = @users     ||= Repositories::UsersInActiveRecord.new

    # --- Use cases: Registry ---------------------------------------------------

    def register_customer
      Application::Registry::RegisterCustomer.new(customers: customers)
    end

    def register_vehicle
      Application::Registry::RegisterVehicle.new(vehicles: vehicles, customers: customers)
    end

    # --- Use cases: Catalog ----------------------------------------------------

    def register_service
      Application::Catalog::RegisterService.new(services: services)
    end

    # --- Use cases: Inventory --------------------------------------------------

    def register_part = Application::Inventory::RegisterPart.new(parts: parts)
    def restock_part  = Application::Inventory::RestockPart.new(parts: parts)

    # --- Use cases: Workshop ---------------------------------------------------

    def open_service_order
      Application::Workshop::OpenServiceOrder.new(
        orders: orders, vehicles: vehicles, customers: customers
      )
    end

    def add_service_to_order
      Application::Workshop::AddServiceToOrder.new(orders: orders, services: services)
    end

    def add_part_to_order
      Application::Workshop::AddPartToOrder.new(orders: orders, parts: parts)
    end

    def start_diagnosis = Application::Workshop::StartDiagnosis.new(orders: orders)
    def send_quote      = Application::Workshop::SendQuote.new(orders: orders)
    def complete_work   = Application::Workshop::CompleteWork.new(orders: orders)
    def deliver_vehicle = Application::Workshop::DeliverVehicle.new(orders: orders)

    # The three commands that move stock as well as the order.
    def approve_quote = Application::Workshop::ApproveQuote.new(orders: orders, parts: parts)
    def reject_quote  = Application::Workshop::RejectQuote.new(orders: orders, parts: parts)

    def cancel_service_order
      Application::Workshop::CancelServiceOrder.new(orders: orders, parts: parts)
    end
  end
end
