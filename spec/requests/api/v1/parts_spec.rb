require "swagger_helper"

RSpec.describe "api/v1/parts", type: :request do
  let(:user) { create_user }
  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }
  let(:auth_headers) { { "Authorization" => send(:Authorization) } }

  path "/api/v1/parts" do
    parameter name: :Authorization, in: :header, type: :string, required: true

    post "Registers a part" do
      tags "Parts"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          part: {
            type: :object,
            properties: {
              sku: { type: :string, example: "FIL-OL01" },
              description: { type: :string, example: "Filtro de óleo" },
              unit_price: { type: :string, example: "45.00" },
              quantity_on_hand: { type: :integer, example: 25 },
              minimum_stock: { type: :integer, example: 5 }
            },
            required: %w[sku description unit_price]
          }
        },
        required: [ "part" ]
      }

      response "201", "part registered" do
        let(:body) do
          { part: { sku: "fil-ol01", description: "Filtro de óleo",
                    unit_price: "45.00", quantity_on_hand: 25, minimum_stock: 5 } }
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["sku"]).to eq("FIL-OL01") # normalised by the aggregate
          expect(payload["below_minimum"]).to be(false)
        end
      end

      response "409", "SKU already exists" do
        schema "$ref" => "#/components/schemas/Error"

        before { create_part(sku: "FIL-OL01") }

        let(:body) { { part: { sku: "FIL-OL01", description: "Duplicada", unit_price: "10" } } }

        run_test!
      end
    end

    get "Lists parts" do
      tags "Parts"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :below_minimum, in: :query, type: :boolean, required: false,
                description: "Only parts that fell under their reorder point"

      response "200", "parts needing replenishment" do
        before do
          create_part(sku: "PLENTY", on_hand: 50, minimum: 5)
          create_part(sku: "SCARCE", on_hand: 1, minimum: 6)
        end

        let(:below_minimum) { true }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["data"].map { |p| p["sku"] }).to eq([ "SCARCE" ])
        end
      end
    end
  end

  path "/api/v1/parts/{id}/restock" do
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :integer, required: true

    post "Records goods received" do
      tags "Parts"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        The only way stock goes up. It only goes down by approving a quote —
        there is no endpoint that writes the balance directly.
      TEXT

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { quantity: { type: :integer, example: 20 } },
        required: [ "quantity" ]
      }

      response "200", "stock replenished" do
        let(:id) { create_part(on_hand: 4, minimum: 6).id }
        let(:body) { { quantity: 20 } }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["quantity_on_hand"]).to eq(24)
          expect(payload["below_minimum"]).to be(false)
        end
      end

      response "422", "non-positive quantity" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { create_part.id }
        let(:body) { { quantity: 0 } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/must be positive/)
        end
      end

      response "404", "part not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 999_999 }
        let(:body) { { quantity: 5 } }

        run_test!
      end
    end
  end

  describe "the balance is not an editable field" do
    # The invariant the whole Inventory context exists to protect. If this ever
    # starts passing a new quantity through, stock can appear from nowhere with
    # no movement behind it.
    it "ignores quantity_on_hand on update" do
      part = create_part(on_hand: 10)

      patch "/api/v1/parts/#{part.id}",
            params: { part: { description: "Filtro novo", quantity_on_hand: 9_999 } },
            headers: auth_headers

      payload = JSON.parse(response.body)
      expect(payload["description"]).to eq("Filtro novo")
      expect(payload["quantity_on_hand"]).to eq(10)
    end

    it "lets the reorder point be revised" do
      part = create_part(on_hand: 5, minimum: 2)

      patch "/api/v1/parts/#{part.id}",
            params: { part: { minimum_stock: 8 } }, headers: auth_headers

      payload = JSON.parse(response.body)
      expect(payload["minimum_stock"]).to eq(8)
      expect(payload["below_minimum"]).to be(true)
    end
  end
end
