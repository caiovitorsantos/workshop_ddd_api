require "net/smtp"

# Tells the customer their service order changed status (Phase 2 requirement:
# "atualização de status via e-mail"). Queued by
# Infrastructure::Events::ActiveJobPublisher, run by Solid Queue (`bin/jobs`).
#
# It receives the event name and the order id and reads the order fresh, so a
# job that runs late still describes the order as it is.
class NotifyCustomerJob < ActiveJob::Base
  # Mailpit restarting must not cost the customer an e-mail.
  retry_on Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout,
           wait: :polynomially_longer, attempts: 5

  def perform(event, order_id)
    container = Infrastructure::Container.new
    order = container.orders.find(order_id)
    customer = order && container.customers.find(order.customer_id)

    # Not an error: e-mail is optional at the counter.
    if customer&.email.nil?
      logger.info("notification_skipped event=#{event} order_id=#{order_id} reason=no_email")
      return
    end

    ServiceOrderMailer.status_changed(event: event, order: order, customer: customer).deliver_now
  end
end
