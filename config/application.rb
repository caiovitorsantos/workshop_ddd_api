require_relative "boot"

require "rails"
# Pick the frameworks you want:
# Only the frameworks this API actually uses. Action Mailer, Active Job and
# Active Storage are left out: the MVP sends no mail, runs no background jobs
# and stores no files, and every framework loaded is code that has to be kept
# patched and audited.
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie" # required by rswag-ui to render the docs page

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OficinaApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "America/Sao_Paulo"
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [ :"pt-BR" ]

    # The four DDD layers live under app/layers, which Zeitwerk treats as an
    # autoload root. Each subdirectory becomes the layer's namespace:
    #
    #   app/layers/domain/...         -> Domain::*          (the heart of the software)
    #   app/layers/application/...    -> Application::*     (use cases, orchestration)
    #   app/layers/infrastructure/... -> Infrastructure::*  (persistence, JWT, ...)
    #
    # The User Interface layer stays in app/controllers, following Rails.
    #
    # Dependency rule: Domain knows nobody. Application knows Domain.
    # Infrastructure and Interface know Application and Domain.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
