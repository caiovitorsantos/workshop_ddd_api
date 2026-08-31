module Domain
  module Workshop
    # ==========================================================================
    # AGGREGATE ROOT: ServiceOrder  (Ordem de Serviço)
    # ==========================================================================
    #
    # The heart of the software (Evans, 2003). Everything the workshop does that
    # sets it apart flows through here: what was requested, what it costs, where
    # it stands in the flow, and when each step happened.
    #
    # Aggregate boundary: ServiceOrder + ServiceItem + PartItem + Quote +
    # OrderStatus. Customer, Vehicle, Service and Part stay outside, referenced
    # by id — they are aggregates belonging to other bounded contexts.
    #
    # Enforced consistency: no object outside this boundary changes state in
    # here. Outsiders *command* (`start_diagnosis!`, `approve_quote!`) and the
    # aggregate decides whether the action is legitimate. That is why every
    # attribute is read-only and the item collections come back frozen.
    #
    class ServiceOrder < Domain::Shared::Entity
      include Domain::Shared::PublishesEvents

      Errors = Domain::Shared::Errors

      attr_reader :number, :customer_id, :vehicle_id, :status, :quote,
                  :diagnosis, :opened_at, :approved_at, :started_at,
                  :completed_at, :delivered_at

      def initialize(
        id: nil, number:, customer_id:, vehicle_id:,
        status: OrderStatus.initial, service_items: [], part_items: [],
        quote: nil, diagnosis: nil, opened_at: nil, approved_at: nil,
        started_at: nil, completed_at: nil, delivered_at: nil, clock: Time
      )
        super(id: id)
        @number        = number
        @customer_id   = customer_id
        @vehicle_id    = vehicle_id
        @status        = status
        @service_items = service_items.dup
        @part_items    = part_items.dup
        @quote         = quote
        @diagnosis     = diagnosis
        @clock         = clock
        @opened_at     = opened_at || clock.current
        @approved_at   = approved_at
        @started_at    = started_at
        @completed_at  = completed_at
        @delivered_at  = delivered_at
        validate!
      end

      # Factory: open a brand new order for an already registered vehicle.
      def self.open(number:, customer_id:, vehicle_id:, clock: Time)
        order = new(number: number, customer_id: customer_id, vehicle_id: vehicle_id, clock: clock)
        order.record_event(Events::ServiceOrderOpened, number: number)
        order
      end

      # --- Queries ------------------------------------------------------------

      def service_items = @service_items.freeze
      def part_items    = @part_items.freeze

      # "Monitoring the average service execution time": the order knows how
      # long it took. The *average* is a read model query, not the aggregate's
      # responsibility.
      def total_duration
        return nil unless delivered_at

        delivered_at - opened_at
      end

      def work_duration
        return nil unless started_at && completed_at

        completed_at - started_at
      end

      # --- Commands: assembling the order -------------------------------------

      def add_service(service_id:, description:, unit_price:, quantity: 1)
        require_draft!("add services")

        @service_items << ServiceItem.new(
          service_id: service_id, description: description,
          unit_price: unit_price, quantity: quantity
        )
        regenerate_quote!
        self
      end

      def add_part(part_id:, description:, unit_price:, quantity:)
        require_draft!("add parts")

        @part_items << PartItem.new(
          part_id: part_id, description: description,
          unit_price: unit_price, quantity: quantity
        )
        regenerate_quote!
        self
      end

      def remove_service(item_id)
        require_draft!("remove services")
        remove_from(@service_items, item_id, "service")
      end

      def remove_part(item_id)
        require_draft!("remove parts")
        remove_from(@part_items, item_id, "part")
      end

      # --- Commands: life cycle -----------------------------------------------

      def start_diagnosis!
        move_to!(OrderStatus::IN_DIAGNOSIS)
        record_event(Events::DiagnosisStarted)
        self
      end

      # Closes the diagnosis and sends the quote to the customer.
      #
      # This is where "automatic status changes as actions happen in the system"
      # lives: there is no endpoint that sets `awaiting_approval`; the status
      # moves because the mechanic recorded a diagnosis.
      def send_quote!(diagnosis:)
        raise Errors::BusinessRuleViolation, "describe the diagnosis before sending the quote" if diagnosis.blank?
        raise Errors::BusinessRuleViolation, "there are no services or parts to quote" if no_items?

        regenerate_quote!
        @diagnosis = diagnosis.to_s.strip
        move_to!(OrderStatus::AWAITING_APPROVAL)
        record_event(Events::QuoteSentToCustomer, total_cents: quote.total.cents)
        self
      end

      def approve_quote!
        move_to!(OrderStatus::IN_PROGRESS)
        @approved_at = @clock.current
        @started_at  = @approved_at
        record_event(Events::QuoteApproved, total_cents: quote.total.cents)
        record_event(Events::WorkStarted)
        self
      end

      def reject_quote!(reason: nil)
        move_to!(OrderStatus::CANCELLED)
        record_event(Events::QuoteRejected, reason: reason)
        self
      end

      def complete!
        move_to!(OrderStatus::COMPLETED)
        @completed_at = @clock.current
        record_event(Events::WorkCompleted)
        self
      end

      def deliver!
        move_to!(OrderStatus::DELIVERED)
        @delivered_at = @clock.current
        record_event(Events::VehicleDelivered, duration_seconds: total_duration&.to_i)
        self
      end

      # The workshop ends the order: wrong vehicle, duplicate entry, customer
      # gave up before there was anything to quote.
      #
      # Deliberately NOT QuoteRejected — nobody refused a price here. Both end
      # the order, but a report on sales lost to price has to be able to tell
      # the two apart.
      def cancel!(reason: nil)
        move_to!(OrderStatus::CANCELLED)
        record_event(Events::ServiceOrderCancelled, reason: reason)
        self
      end

      private

      def no_items?
        @service_items.empty? && @part_items.empty?
      end

      def require_draft!(action)
        return if status.draft?

        raise Errors::InvalidTransition,
              "cannot #{action} while the order is '#{status.label}'"
      end

      def remove_from(collection, item_id, label)
        removed = collection.reject! { |item| item.id == item_id }
        raise Errors::NotFound, "#{label} #{item_id} is not on this order" if removed.nil?

        regenerate_quote!
        self
      end

      def move_to!(target)
        @status = status.transition_to(target)
      end

      def regenerate_quote!
        @quote = Quote.from_items(
          service_items: @service_items, part_items: @part_items, clock: @clock
        )
        record_event(Events::QuoteGenerated, total_cents: @quote.total.cents)
      end

      def validate!
        raise Errors::InvalidValue, "service order number is required"   if number.blank?
        raise Errors::InvalidValue, "service order customer is required" if customer_id.blank?
        raise Errors::InvalidValue, "service order vehicle is required"  if vehicle_id.blank?
      end
    end
  end
end
