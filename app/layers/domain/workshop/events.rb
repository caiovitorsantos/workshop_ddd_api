module Domain
  module Workshop
    # Domain events published by the ServiceOrder aggregate. These are the same
    # orange stickies from the Event Storming board (PLANO_TECH_CHALLENGE.md
    # §2.6) — the drawing and the code speak the same language, one class per
    # sticky, in the same order.
    module Events
      Event = Domain::Shared::DomainEvent

      # --- Opening (pivotal event 1: the order exists) -----------------------
      class ServiceOrderOpened < Event; end

      # --- Diagnosis and quoting ---------------------------------------------
      class DiagnosisStarted < Event; end
      class QuoteGenerated < Event; end

      # --- Pivotal event 2: the order leaves the workshop's hands ------------
      class QuoteSentToCustomer < Event; end

      # --- Pivotal event 3: the customer decides -----------------------------
      class QuoteApproved < Event; end

      # The customer said no to the price. Distinct from ServiceOrderCancelled:
      # both end the order, but only this one is a lost sale, and a report on
      # price rejection has to be able to tell them apart.
      class QuoteRejected < Event; end

      # The workshop ended the order — wrong vehicle, duplicate order, customer
      # gave up before quoting. Not a rejection: nobody refused a price.
      class ServiceOrderCancelled < Event; end

      # --- Execution ---------------------------------------------------------
      class WorkStarted < Event; end
      class WorkCompleted < Event; end

      # --- Pivotal event 4: operation closes, history opens ------------------
      class VehicleDelivered < Event; end
    end
  end
end
