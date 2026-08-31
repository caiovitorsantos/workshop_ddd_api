module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord adapter for the Domain::Workshop::ServiceOrderRepository port.
      #
      # The most involved repository in the project, because ServiceOrder is the
      # only aggregate with internal entities. The rule it exists to enforce:
      # **the aggregate is loaded and saved whole**. There is no way to fetch
      # just the items, and no way to save an item without its order — that is
      # what an aggregate boundary means once it reaches the database.
      class ServiceOrdersInActiveRecord < Domain::Workshop::ServiceOrderRepository
        Record = Records::ServiceOrder

        # Saves the root and reconciles its items in one transaction. Items are
        # replaced wholesale rather than diffed: the collections are small
        # (a handful per order), and a diff would be more code and more ways to
        # leave the aggregate half-written.
        def save(order)
          Record.transaction do
            record = order.new_record? ? Record.new : Record.lock.find(order.id)

            record.assign_attributes(
              number: order.number,
              customer_id: order.customer_id,
              vehicle_id: order.vehicle_id,
              status: order.status.to_s,
              diagnosis: order.diagnosis,
              labour_total_cents: order.quote&.labour_total&.cents || 0,
              parts_total_cents: order.quote&.parts_total&.cents || 0,
              quote_generated_at: order.quote&.generated_at,
              opened_at: order.opened_at,
              approved_at: order.approved_at,
              started_at: order.started_at,
              completed_at: order.completed_at,
              delivered_at: order.delivered_at
            )
            record.save!

            replace_items(record, order)

            to_domain(record.reload)
          end
        end

        def find(id)
          record = with_items.find_by(id: id)
          record && to_domain(record)
        end

        def find_by_number(number)
          record = with_items.find_by(number: number.to_s)
          record && to_domain(record)
        end

        # Claims the next order number.
        #
        # `UPDATE ... RETURNING` is atomic and takes a row lock, so two
        # simultaneous opens serialise and cannot claim the same number. Because
        # it is transactional (unlike a PostgreSQL sequence), a rolled-back open
        # does not burn a number — the numbering stays gapless, which is what
        # people expect from a document they read out to a customer. See the
        # AddServiceOrderNumberCounter migration.
        COUNTER = "service_order_number".freeze

        def next_number
          # Upsert rather than UPDATE: the counter row seeds itself on first
          # use. A migration's INSERT is not carried into `schema.rb`, so a
          # database loaded from the schema — every test run, every fresh
          # checkout — would otherwise start with no row to increment.
          #
          # ON CONFLICT DO UPDATE takes the same row lock a plain UPDATE would,
          # so concurrent opens still serialise and cannot claim one number
          # twice.
          value = Record.connection.select_value(<<~SQL.squish)
            INSERT INTO counters (name, value) VALUES ('#{COUNTER}', 1)
            ON CONFLICT (name) DO UPDATE SET value = counters.value + 1
            RETURNING value
          SQL

          format("OS-%06d", value)
        end

        def list(page: 1, per_page: 25, status: nil, customer_id: nil)
          scope = with_items.order(opened_at: :desc)
          scope = scope.where(status: status.to_s) if status.present?
          scope = scope.where(customer_id: customer_id) if customer_id.present?

          total    = scope.count
          page     = [ page.to_i, 1 ].max
          per_page = per_page.to_i.clamp(1, 100)

          records = scope.offset((page - 1) * per_page).limit(per_page)

          [ records.map { |r| to_domain(r) }, total ]
        end

        # Read model, not an aggregate operation: it spans many orders and
        # belongs to none of them. Computed in SQL rather than by loading
        # aggregates and averaging in Ruby — the answer is one number, and
        # loading a year of orders to produce it would be absurd.
        #
        # Returns seconds, or nil when no order has been delivered yet.
        def average_execution_time(since: nil)
          delivered(since: since).average(
            Arel.sql("EXTRACT(EPOCH FROM (delivered_at - opened_at))")
          )&.to_f
        end

        # The sample size behind the average. Reported alongside it because an
        # average of two orders and an average of two hundred are not the same
        # claim.
        def delivered_count(since: nil)
          delivered(since: since).count
        end

        private

        def delivered(since: nil)
          scope = Record.where.not(delivered_at: nil)
          since ? scope.where(opened_at: since..) : scope
        end

        def with_items
          Record.includes(:service_items, :part_items)
        end

        def replace_items(record, order)
          record.service_items.destroy_all
          record.part_items.destroy_all

          order.service_items.each do |item|
            record.service_items.create!(
              service_id: item.service_id,
              description: item.description,
              unit_price_cents: item.unit_price.cents,
              quantity: item.quantity
            )
          end

          order.part_items.each do |item|
            record.part_items.create!(
              part_id: item.part_id,
              description: item.description,
              unit_price_cents: item.unit_price.cents,
              quantity: item.quantity
            )
          end
        end

        def to_domain(record)
          Domain::Workshop::ServiceOrder.new(
            id: record.id,
            number: record.number,
            customer_id: record.customer_id,
            vehicle_id: record.vehicle_id,
            status: Domain::Workshop::OrderStatus.parse(record.status),
            service_items: record.service_items.map { |i| to_domain_service_item(i) },
            part_items: record.part_items.map { |i| to_domain_part_item(i) },
            quote: to_domain_quote(record),
            diagnosis: record.diagnosis,
            opened_at: record.opened_at,
            approved_at: record.approved_at,
            started_at: record.started_at,
            completed_at: record.completed_at,
            delivered_at: record.delivered_at
          )
        end

        def to_domain_quote(record)
          return nil if record.quote_generated_at.nil?

          Domain::Workshop::Quote.new(
            labour_total: Domain::Shared::Money.new(cents: record.labour_total_cents),
            parts_total: Domain::Shared::Money.new(cents: record.parts_total_cents),
            generated_at: record.quote_generated_at
          )
        end

        def to_domain_service_item(item)
          Domain::Workshop::ServiceItem.new(
            id: item.id,
            service_id: item.service_id,
            description: item.description,
            unit_price: Domain::Shared::Money.new(cents: item.unit_price_cents),
            quantity: item.quantity
          )
        end

        def to_domain_part_item(item)
          Domain::Workshop::PartItem.new(
            id: item.id,
            part_id: item.part_id,
            description: item.description,
            unit_price: Domain::Shared::Money.new(cents: item.unit_price_cents),
            quantity: item.quantity
          )
        end
      end
    end
  end
end
