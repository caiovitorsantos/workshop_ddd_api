source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Infrastructure layer: authentication for the administrative APIs.
gem "bcrypt", "~> 3.1.7"
gem "jwt", "~> 3.1"

# Interface layer: OpenAPI/Swagger documentation generated from the specs.
gem "rswag-api", "~> 2.16"
gem "rswag-ui", "~> 2.16"

gem "rack-cors"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  gem "rspec-rails", "~> 8.0"
  gem "rswag-specs", "~> 2.16"
  gem "factory_bot_rails", "~> 6.5"
  gem "shoulda-matchers", "~> 6.5"
  gem "simplecov", require: false

  # Static security analysis — feeds the Phase 1 vulnerability report.
  gem "brakeman", require: false
  gem "bundler-audit", require: false

  gem "rubocop-rails-omakase", require: false
end
