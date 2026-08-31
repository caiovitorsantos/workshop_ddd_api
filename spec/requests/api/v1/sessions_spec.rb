require "swagger_helper"

# Authentication is a graded Phase 1 requirement, so it gets its own
# integration spec — and, through rswag, its own Swagger entry.
RSpec.describe "api/v1/session", type: :request do
  let(:users) { Infrastructure::Persistence::Repositories::UsersInActiveRecord.new }

  before do
    users.save(
      Domain::Identity::User.new(
        name: "Gabriela Gerente", email: "gerente@oficina.test",
        role: :manager, password_digest: "placeholder"
      ),
      password: "senha-forte-123"
    )
  end

  path "/api/v1/session" do
    post "Signs in and returns a JWT" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: "gerente@oficina.local" },
          password: { type: :string, example: "oficina123" }
        },
        required: %w[email password]
      }

      response "201", "authenticated" do
        schema type: :object,
               properties: {
                 token: { type: :string },
                 expires_in: { type: :integer, example: 28_800 },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string },
                     role: { type: :string, enum: %w[front_desk mechanic manager] }
                   }
                 }
               }

        let(:body) { { email: "gerente@oficina.test", password: "senha-forte-123" } }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["user"]["role"]).to eq("manager")

          # The issued token must actually verify, not merely look like a JWT.
          claims = Infrastructure::Auth::JwtToken.verify(payload["token"])
          expect(claims["role"]).to eq("manager")
        end
      end

      response "401", "wrong password" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { email: "gerente@oficina.test", password: "senha-errada" } }

        run_test! do |response|
          # Deliberately the same message as for an unknown email, so the
          # endpoint cannot be used to enumerate valid accounts.
          expect(JSON.parse(response.body)["error"]).to eq("invalid credentials")
        end
      end

      response "401", "unknown email" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { email: "ninguem@oficina.test", password: "senha-forte-123" } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to eq("invalid credentials")
        end
      end
    end
  end
end
