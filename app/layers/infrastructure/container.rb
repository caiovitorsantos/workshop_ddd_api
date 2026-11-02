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

    # --- Ports: unit of work and domain events ---------------------------------

    def transaction = @transaction ||= Persistence::ActiveRecordTransactionManager.new
    def events      = @events      ||= Events::LoggingPublisher.new(logger: Rails.logger)

    # --- Use cases: Registry ---------------------------------------------------

    def register_customer
      Application::Registry::RegisterCustomer.new(customers: customers)
    end

    def update_customer_contact
      Application::Registry::UpdateCustomerContact.new(customers: customers)
    end

    def remove_customer = Application::Registry::RemoveCustomer.new(customers: customers)

    def register_vehicle
      Application::Registry::RegisterVehicle.new(vehicles: vehicles, customers: customers)
    end

    def correct_vehicle_details
      Application::Registry::CorrectVehicleDetails.new(vehicles: vehicles)
    end

    def remove_vehicle = Application::Registry::RemoveVehicle.new(vehicles: vehicles)

    # --- Use cases: Catalog ----------------------------------------------------

    def register_service
      Application::Catalog::RegisterService.new(services: services)
    end

    def revise_service = Application::Catalog::ReviseService.new(services: services)
    def retire_service = Application::Catalog::RetireService.new(services: services)
    def remove_service = Application::Catalog::RemoveService.new(services: services)

    # --- Use cases: Inventory --------------------------------------------------

    def register_part = Application::Inventory::RegisterPart.new(parts: parts)
    def revise_part   = Application::Inventory::RevisePart.new(parts: parts)
    def remove_part   = Application::Inventory::RemovePart.new(parts: parts)

    # Locks the part's row while it adds the delivery, hence the unit of work.
    def restock_part
      Application::Inventory::RestockPart.new(
        parts: parts, transaction: transaction, events: events
      )
    end

    # --- Use cases: Workshop ---------------------------------------------------

    def open_service_order
      Application::Workshop::OpenServiceOrder.new(
        orders: orders, customers: customers, vehicles: vehicles, services: services,
        parts: parts, transaction: transaction, events: events
      )
    end

    def add_service_to_order
      Application::Workshop::AddServiceToOrder.new(
        orders: orders, services: services, events: events
      )
    end

    def add_part_to_order = moving_stock(Application::Workshop::AddPartToOrder)

    def start_diagnosis = order_command(Application::Workshop::StartDiagnosis)
    def send_quote      = order_command(Application::Workshop::SendQuote)
    def complete_work   = order_command(Application::Workshop::CompleteWork)
    def deliver_vehicle = order_command(Application::Workshop::DeliverVehicle)

    def approve_quote        = moving_stock(Application::Workshop::ApproveQuote)
    def reject_quote         = moving_stock(Application::Workshop::RejectQuote)
    def cancel_service_order = moving_stock(Application::Workshop::CancelServiceOrder)

    def decide_quote
      Application::Workshop::DecideQuote.new(
        orders: orders, approve_quote: approve_quote, reject_quote: reject_quote
      )
    end

    private

    # Life cycle commands that touch only the order.
    def order_command(use_case) = use_case.new(orders: orders, events: events)

    # Commands that move an order *and* a part's stock: two bounded contexts,
    # one unit of work, so they all get the same collaborators.
    def moving_stock(use_case)
      use_case.new(orders: orders, parts: parts, transaction: transaction, events: events)
    end
  end
end
