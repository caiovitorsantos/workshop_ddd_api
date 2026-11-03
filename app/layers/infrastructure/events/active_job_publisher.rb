module Infrastructure
  module Events
    # EventPublisher adapter that, besides logging every event (LoggingPublisher),
    # queues an e-mail to the customer for the ones they care about.
    #
    # The job carries the event name and the order id, never the order: it may
    # run after the order has moved on, and it reads the order fresh.
    #
    # Use cases publish only after their unit of work commits, so a rolled back
    # operation never e-mails anyone.
    class ActiveJobPublisher < LoggingPublisher
      # One e-mail per status change the customer sees. QuoteApproved is left
      # out on purpose — WorkStarted fires with it and says the same thing — and
      # so is QuoteGenerated, recorded on every line added to a draft.
      NOTIFIED = %w[
        service_order_opened diagnosis_started quote_sent_to_customer
        work_started work_completed vehicle_delivered
        quote_rejected service_order_cancelled
      ].freeze

      def publish(events)
        super
        events.each do |event|
          next unless NOTIFIED.include?(event.name)

          NotifyCustomerJob.perform_later(event.name, event.aggregate_id)
        end
      end
    end
  end
end
