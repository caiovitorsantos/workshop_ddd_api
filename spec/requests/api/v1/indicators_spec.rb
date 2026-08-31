require "swagger_helper"

RSpec.describe "api/v1/indicators", type: :request do
  let(:user) { create_user }
  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }
  let(:auth_headers) { { "Authorization" => send(:Authorization) } }

  # Drives one order all the way to delivery, with the clock moved forward so
  # the duration is exact instead of "a few milliseconds".
  def deliver_order_taking(hours)
    order = order_awaiting_approval

    Application::Workshop::ApproveQuote.call(orders: orders, parts: parts, id: order.id)
    Application::Workshop::CompleteWork.call(repository: orders, id: order.id)
    Application::Workshop::DeliverVehicle.call(repository: orders, id: order.id)

    # The domain stamps the timeline; the spec only rewrites it to simulate the
    # passage of time, which is why it reaches for the record directly.
    record = Infrastructure::Persistence::Records::ServiceOrder.find(order.id)
    record.update!(opened_at: record.delivered_at - hours.hours)
    order
  end

  path "/api/v1/indicators/average_execution_time" do
    parameter name: :Authorization, in: :header, type: :string, required: true

    get "Average time from opening to delivery" do
      tags "Indicators"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :since, in: :query, type: :string, required: false,
                description: "ISO 8601 instant; only orders opened after it count"

      response "200", "indicator computed" do
        schema type: :object,
               properties: {
                 since: { type: :string, format: :"date-time", nullable: true },
                 delivered_orders: { type: :integer, example: 12 },
                 average_execution_seconds: { type: :integer, nullable: true, example: 16_200 },
                 average_execution_human: { type: :string, nullable: true, example: "4h 30min" }
               }

        before do
          deliver_order_taking(4)
          deliver_order_taking(6)
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["delivered_orders"]).to eq(2)
          expect(payload["average_execution_seconds"]).to eq(5.hours.to_i)
          expect(payload["average_execution_human"]).to eq("5h 0min")
        end
      end

      response "400", "malformed since" do
        schema "$ref" => "#/components/schemas/Error"

        let(:since) { "ontem" }

        run_test!
      end

      response "401", "no token" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer nope" }

        run_test!
      end
    end
  end

  describe "the numbers" do
    it "reports nothing rather than zero when no order has been delivered" do
      order_awaiting_approval # opened, never delivered

      get "/api/v1/indicators/average_execution_time", headers: auth_headers

      payload = JSON.parse(response.body)
      expect(payload["delivered_orders"]).to eq(0)
      # nil, not 0 — "no data" and "instantaneous" are different claims.
      expect(payload["average_execution_seconds"]).to be_nil
      expect(payload["average_execution_human"]).to be_nil
    end

    it "counts only delivered orders, ignoring ones still in the shop" do
      deliver_order_taking(4)
      order_awaiting_approval

      get "/api/v1/indicators/average_execution_time", headers: auth_headers

      expect(JSON.parse(response.body)["delivered_orders"]).to eq(1)
    end

    it "honours the since window" do
      deliver_order_taking(4)

      get "/api/v1/indicators/average_execution_time",
          params: { since: 1.hour.from_now.iso8601 }, headers: auth_headers

      expect(JSON.parse(response.body)["delivered_orders"]).to eq(0)
    end

    it "formats sub-hour averages without a leading zero hour" do
      deliver_order_taking(0.5)

      get "/api/v1/indicators/average_execution_time", headers: auth_headers

      expect(JSON.parse(response.body)["average_execution_human"]).to eq("30min")
    end

    # The sample size travels with the average because two orders and two
    # hundred are not the same claim.
    it "reports the sample size alongside the average" do
      3.times { deliver_order_taking(2) }

      get "/api/v1/indicators/average_execution_time", headers: auth_headers

      payload = JSON.parse(response.body)
      expect(payload["delivered_orders"]).to eq(3)
      expect(payload["average_execution_human"]).to eq("2h 0min")
    end
  end
end
