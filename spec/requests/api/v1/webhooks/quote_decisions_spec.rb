require "swagger_helper"

RSpec.describe "api/v1/webhooks/quote_decisions", type: :request do
  let(:secret) { "segredo-do-webhook" }

  before do
    Api::V1::Webhooks::QuoteDecisionsController::RATE_LIMIT_STORE.clear
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUOTE_WEBHOOK_SECRET").and_return(secret)
  end

  def sign(payload) = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)

  def decide(body, signature: sign(body.to_json))
    post "/api/v1/webhooks/quote_decisions",
         params: body.to_json,
         headers: { "Content-Type" => "application/json", "X-Signature" => signature }
  end

  path "/api/v1/webhooks/quote_decisions" do
    post "Receives the customer's decision on a quote (external system)" do
      tags "Webhooks"
      consumes "application/json"
      produces "application/json"
      description <<~TEXT
        Called by the system that shows the quote to the customer. No JWT: the
        caller proves itself with `X-Signature`, the hex HMAC-SHA256 of the raw
        request body under the shared secret `QUOTE_WEBHOOK_SECRET`.

        Idempotent: repeating a decision that was already applied answers 200
        and changes nothing. A contradicting decision, or one for an order not
        awaiting approval, is a 409. Rate limited to 30 requests per minute.
      TEXT

      parameter name: :"X-Signature", in: :header, type: :string, required: true,
                description: "hex HMAC-SHA256 of the raw body"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          order_number: { type: :string, example: "OS-000042" },
          decision: { type: :string, enum: %w[approved rejected] },
          reason: { type: :string, example: "Preço acima do esperado" }
        },
        required: %w[order_number decision]
      }

      let(:order) { order_awaiting_approval }
      let(:body) { { order_number: order.number, decision: "approved" } }
      let(:"X-Signature") { sign(body.to_json) }

      response "200", "decision applied (or already applied)" do
        run_test! do |response|
          expect(JSON.parse(response.body)).to include("number" => order.number, "status" => "in_progress")
        end
      end

      response "401", "signature missing or wrong" do
        schema "$ref" => "#/components/schemas/Error"

        let(:"X-Signature") { sign("outro corpo") }

        run_test!
      end

      response "404", "no such order" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { order_number: "OS-999999", decision: "approved" } }

        run_test!
      end

      response "409", "contradicts a decision already applied, or order not awaiting approval" do
        schema "$ref" => "#/components/schemas/Error"

        let(:order) { order_in_progress }
        let(:body) { { order_number: order.number, decision: "rejected" } }

        run_test!
      end

      response "422", "unknown decision" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { order_number: order.number, decision: "maybe" } }

        run_test!
      end
    end
  end

  describe "idempotency" do
    it "applies a repeated approval once — the stock is deducted once" do
      part  = create_part(on_hand: 10)
      order = order_awaiting_approval(part: part, part_quantity: 2)
      body  = { order_number: order.number, decision: "approved" }

      2.times { decide(body) }

      expect(response).to have_http_status(:ok)
      expect(parts.find(part.id).quantity_on_hand).to eq(8)
    end

    it "applies a repeated rejection once" do
      order = order_awaiting_approval
      body  = { order_number: order.number, decision: "rejected", reason: "Caro demais" }

      2.times { decide(body) }

      expect(response).to have_http_status(:ok)
      expect(orders.find(order.id).status).to be_cancelled
    end

    it "refuses an approval after a rejection" do
      order = order_awaiting_approval
      decide({ order_number: order.number, decision: "rejected" })

      decide({ order_number: order.number, decision: "approved" })

      expect(response).to have_http_status(:conflict)
    end
  end

  describe "authentication" do
    it "refuses everything when no secret is configured, whatever the signature" do
      allow(ENV).to receive(:[]).with("QUOTE_WEBHOOK_SECRET").and_return(nil)
      body = { order_number: order_awaiting_approval.number, decision: "approved" }

      decide(body, signature: OpenSSL::HMAC.hexdigest("SHA256", "", body.to_json))

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses a request without a signature" do
      decide({ order_number: "OS-000001", decision: "approved" }, signature: nil)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "cuts off a caller past 30 requests a minute" do
    31.times { decide({ order_number: "OS-999999", decision: "approved" }) }

    expect(response).to have_http_status(:too_many_requests)
  end
end
