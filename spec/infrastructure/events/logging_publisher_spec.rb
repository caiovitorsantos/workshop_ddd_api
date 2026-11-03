require "rails_helper"

RSpec.describe Infrastructure::Events::LoggingPublisher do
  let(:output) { StringIO.new }
  let(:publisher) { described_class.new(logger: Logger.new(output, formatter: ->(*, msg) { "#{msg}\n" })) }

  it "writes one searchable key=value line per event" do
    event = Domain::Workshop::Events::QuoteApproved.new(
      aggregate_id: 42, occurred_at: Time.utc(2026, 11, 2, 20, 31, 7), payload: { total_cents: 21_000 }
    )

    publisher.publish([ event ])

    expect(output.string).to eq(
      "domain_event=quote_approved aggregate_id=42 occurred_at=2026-11-02T20:31:07Z total_cents=21000\n"
    )
  end

  it "writes nothing when there is nothing to publish" do
    publisher.publish([])

    expect(output.string).to be_empty
  end
end
