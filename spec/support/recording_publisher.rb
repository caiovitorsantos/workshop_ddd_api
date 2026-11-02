# An EventPublisher adapter that only remembers what it was handed.
#
#   use_case = described_class.new(..., events: events)  # `events` from WorkshopFixtures
#   use_case.call(id: order.id)
#   expect(events.names).to eq(%w[quote_approved work_started stock_deducted])
class RecordingPublisher < Application::Shared::EventPublisher
  def initialize = @published = []

  attr_reader :published

  def publish(events) = @published.concat(events)

  def names = published.map(&:name)
end
