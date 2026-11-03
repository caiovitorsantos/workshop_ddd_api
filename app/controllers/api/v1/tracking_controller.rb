module Api
  module V1
    # Public order tracking — the customer following their own repair.
    #
    # **The only route in the system without a JWT.** The customer has a number
    # printed on a slip, not an account, so requiring a token would defeat the
    # requirement ("permitir consulta por parte do cliente via API para
    # acompanhar o progresso").
    #
    # That makes this the most security-sensitive endpoint here, for one reason:
    # order numbers are sequential. Anyone can walk OS-000001 upwards. So the
    # question is not "who is asking" — we cannot know — but **"what is safe to
    # answer to someone who guessed a number"**.
    #
    # What it returns: the number, the status and the milestone dates.
    # What it deliberately withholds, and why:
    #
    #   - money (quote totals) — an enumerator would harvest the workshop's
    #     entire revenue, order by order;
    #   - the diagnosis — free text about someone's car, often with detail the
    #     owner would not publish;
    #   - the customer — name, tax id, contact;
    #   - the vehicle, **including the plate** — this is the subtle one. It is
    #     tempting to echo the plate so the customer can confirm it is their car,
    #     but walking the numbers would then yield every plate the workshop has
    #     ever serviced. The customer already knows which car they dropped off.
    #
    # What remains is what a customer standing at the counter could ask about
    # their own job, and nothing more.
    class TrackingController < BaseController
      skip_authentication only: :show

      # A dedicated store rather than Rails.cache, for two reasons: rate-limit
      # counters have nothing to do with the application's general caching, and
      # the test environment's null store would otherwise make the limiter a
      # no-op exactly where it needs proving.
      #
      # Caveat worth knowing: a MemoryStore is per-process, so with N Puma
      # workers the effective ceiling is 30 × N. Fine for a single-container
      # MVP; the day this runs behind more than one process, point it at Redis.
      RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 2.megabytes)

      # The endpoint is unauthenticated and enumerable, so it gets a ceiling.
      # Not a defence against a determined scraper — it is what stops a trivial
      # one from walking the whole sequence in a minute.
      rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE, only: :show

      def show
        render_found(
          repository.find_by_number(params[:number]),
          with: TrackingPresenter, missing: "service order"
        )
      end

      private

      def repository = container.orders
    end
  end
end
