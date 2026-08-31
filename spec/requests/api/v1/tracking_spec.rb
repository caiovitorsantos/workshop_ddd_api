require "swagger_helper"

RSpec.describe "api/v1/tracking", type: :request do
  # The limiter counts by IP, and every example here shares one. Without this,
  # adding a few more examples would silently start 429-ing the earlier ones.
  before { Api::V1::TrackingController::RATE_LIMIT_STORE.clear }

  path "/api/v1/tracking/{number}" do
    parameter name: :number, in: :path, type: :string, required: true,
              description: "Order number as printed on the customer's slip",
              example: "OS-000001"

    get "Tracks a service order (public)" do
      tags "Tracking"
      produces "application/json"
      description <<~TEXT
        The only endpoint that does not require a JWT: the customer has a number
        on a slip, not an account.

        Because order numbers are sequential and therefore guessable, the
        response is deliberately minimal — no money, no diagnosis, no customer
        details, and no license plate. Rate limited to 30 requests per minute.
      TEXT

      response "200", "order found" do
        schema type: :object,
               properties: {
                 number: { type: :string, example: "OS-000001" },
                 status: { type: :string, example: "awaiting_approval" },
                 status_label: { type: :string, example: "Aguardando aprovação" },
                 waiting_on_you: { type: :boolean },
                 opened_at: { type: :string, format: :"date-time" },
                 approved_at: { type: :string, format: :"date-time", nullable: true },
                 completed_at: { type: :string, format: :"date-time", nullable: true },
                 delivered_at: { type: :string, format: :"date-time", nullable: true }
               },
               required: %w[number status status_label]

        let(:number) { order_awaiting_approval.number }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["status_label"]).to eq("Aguardando aprovação")
          expect(payload["waiting_on_you"]).to be(true)
        end
      end

      response "404", "no such order" do
        schema "$ref" => "#/components/schemas/Error"

        let(:number) { "OS-999999" }

        run_test!
      end
    end
  end

  describe "what it refuses to leak" do
    # Order numbers are sequential, so anyone can walk OS-000001 upwards. These
    # are the assertions that make that walk worthless. If one of them ever
    # starts failing, someone has widened the payload without thinking about
    # who is on the other end.
    subject(:payload) do
      order = order_awaiting_approval
      get "/api/v1/tracking/#{order.number}"
      JSON.parse(response.body)
    end

    it "answers without any credential at all" do
      expect(payload).to include("status")
      expect(response).to have_http_status(:ok)
    end

    it "withholds the money" do
      expect(payload.keys).not_to include("quote", "total", "labour_total", "parts_total")
    end

    it "withholds the diagnosis — free text about someone's car" do
      expect(payload).not_to have_key("diagnosis")
    end

    it "withholds the customer" do
      expect(payload.keys).not_to include("customer_id", "customer", "tax_id", "name")
    end

    # The subtle one: echoing the plate so the customer can confirm their car
    # would let an enumerator harvest every plate the workshop has serviced.
    it "withholds the vehicle, including the plate" do
      expect(payload.keys).not_to include("vehicle_id", "vehicle", "plate")
    end

    it "withholds the items" do
      expect(payload.keys).not_to include("service_items", "part_items")
    end

    it "exposes exactly the agreed set and nothing else" do
      expect(payload.keys).to match_array(
        %w[number status status_label waiting_on_you
           opened_at approved_at completed_at delivered_at]
      )
    end
  end

  describe "rate limiting" do
    it "serves a caller who stays under the ceiling" do
      number = order_awaiting_approval.number

      30.times { get "/api/v1/tracking/#{number}" }

      expect(response).to have_http_status(:ok)
    end

    it "cuts off a caller walking the sequence" do
      number = order_awaiting_approval.number

      31.times { get "/api/v1/tracking/#{number}" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
