# Coverage has to be started before any application code loads.
require "simplecov"

# `rake rswag:specs:swaggerize` re-runs the request specs with --dry-run just to
# harvest the OpenAPI metadata: no example body executes, so coverage would come
# back at 0% and fail the build for entirely the wrong reason. Measure only on
# real runs.
unless ARGV.include?("--dry-run")
  SimpleCov.start "rails" do
    enable_coverage :branch

    skip "/spec/"
    skip "/config/"
    skip "/db/"

    # Excluded because there is genuinely nothing to test in them, and counting
    # them would only dilute the number that matters:
    #   - repository ports are abstract interfaces whose every method body is
    #     `raise NotImplementedError`; the adapters implementing them ARE tested;
    #   - record classes are declarative table mappings (`self.table_name = ...`)
    #     with no behaviour of their own — all logic lives in the domain.
    skip %r{app/layers/domain/.*_repository\.rb\z}
    skip "app/layers/infrastructure/persistence/records"

    # The layers show up separately in the report: this is how we demonstrate
    # the "80% on the critical domains" required by Phase 1.
    group "Domain",         "app/layers/domain"
    group "Application",    "app/layers/application"
    group "Infrastructure", "app/layers/infrastructure"
    group "Interface",      "app/controllers"

    minimum_coverage line: 80, branch: 70
  end
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The test suite is running in production mode!") if Rails.env.production?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
