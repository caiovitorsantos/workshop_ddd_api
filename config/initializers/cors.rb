# Cross-Origin Resource Sharing.
#
# The mobile/web client that lets a customer track their order lives on another
# origin. ALLOWED_ORIGINS is a comma-separated allowlist, and it defaults to
# localhost — never to "*", which would let any site on the internet call this
# API with a user's token.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:5173").split(",")

    resource "/api/*",
             headers: :any,
             methods: [ :get, :post, :patch, :put, :delete, :options, :head ],
             expose: [ "Authorization" ],
             max_age: 600
  end
end
