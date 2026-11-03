# The customer-facing e-mail for each status change, in Portuguese — the
# customer reads it, not another system.
#
# Like the public tracking endpoint, it says where the order stands and nothing
# more: it goes to an inbox, and the plate and diagnosis stay out of it. The
# quote total is the exception, in the one e-mail that asks for a decision.
class ServiceOrderMailer < ActionMailer::Base
  MESSAGES = {
    "service_order_opened" => "Recebemos seu veículo e abrimos a ordem de serviço.",
    "diagnosis_started" => "Começamos o diagnóstico do seu veículo.",
    "quote_sent_to_customer" => "O orçamento está pronto e aguarda a sua aprovação.",
    "work_started" => "Orçamento aprovado: o serviço já está em execução.",
    "work_completed" => "O serviço foi concluído. Seu veículo está pronto para retirada.",
    "vehicle_delivered" => "Veículo entregue. Obrigado pela preferência!",
    "quote_rejected" => "Registramos a recusa do orçamento e encerramos a ordem de serviço.",
    "service_order_cancelled" => "A ordem de serviço foi cancelada."
  }.freeze

  # The status each event leads to. The job runs a moment after the event, and
  # by then the order may have moved on (a quote approved by webhook before
  # its e-mail went out): the e-mail names the status of *its* event, never
  # the order's current one.
  Status = Domain::Workshop::OrderStatus
  STATUS_AFTER = {
    "service_order_opened" => Status::RECEIVED,
    "diagnosis_started" => Status::IN_DIAGNOSIS,
    "quote_sent_to_customer" => Status::AWAITING_APPROVAL,
    "work_started" => Status::IN_PROGRESS,
    "work_completed" => Status::COMPLETED,
    "vehicle_delivered" => Status::DELIVERED,
    "quote_rejected" => Status::CANCELLED,
    "service_order_cancelled" => Status::CANCELLED
  }.freeze

  def status_changed(event:, order:, customer:)
    @message  = MESSAGES.fetch(event)
    @status   = Status::LABELS.fetch(STATUS_AFTER.fetch(event))
    @order    = order
    @customer = customer
    @quote    = order.quote if event == "quote_sent_to_customer"
    @tracking_url = "#{ENV.fetch("PUBLIC_URL", "http://localhost:3000")}/api/v1/tracking/#{order.number}"

    mail(to: customer.email, subject: "Ordem de serviço #{order.number}: #{@status}")
  end
end
