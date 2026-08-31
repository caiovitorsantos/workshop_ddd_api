module Api
  module V1
    # Parts and consumables, with stock control.
    #
    # Note the shape of this controller: there is **no way to write
    # `quantity_on_hand`**. Stock goes up through `POST /parts/:id/restock` and
    # down only by approving a quote. Both are movements the aggregate records;
    # neither is a field you can edit. That is the whole point of the Inventory
    # context.
    class PartsController < BaseController
      def index
        parts, total = repository.list(
          page: page, per_page: per_page,
          below_minimum: params[:below_minimum].present?
        )

        render json: {
          data: parts.map { |p| serialize(p) },
          pagination: { page: page, per_page: per_page, total: total }
        }
      end

      def show
        part = repository.find(params[:id])
        return render_error("part not found", :not_found) unless part

        render json: serialize(part)
      end

      def create
        result = Application::Inventory::RegisterPart.call(
          parts: repository,
          sku: part_params[:sku],
          description: part_params[:description],
          unit_price: part_params[:unit_price],
          quantity_on_hand: part_params.fetch(:quantity_on_hand, 0),
          minimum_stock: part_params.fetch(:minimum_stock, 0)
        )

        respond_with(result, success: :created) { |part| serialize(part) }
      end

      def update
        part = repository.find(params[:id])
        return render_error("part not found", :not_found) unless part

        # `quantity_on_hand` is deliberately not among the editable attributes.
        revised = part.revise(
          description: part_params.fetch(:description, part.description),
          unit_price: unit_price_or(part.unit_price),
          minimum_stock: part_params.fetch(:minimum_stock, part.minimum_stock)
        )

        render json: serialize(repository.save(revised))
      rescue Domain::Shared::Errors::Base => e
        render_error(e.message, :unprocessable_entity)
      end

      def restock
        result = Application::Inventory::RestockPart.call(
          parts: repository, id: params[:id], quantity: params[:quantity]
        )

        respond_with(result) { |part| serialize(part) }
      end

      def destroy
        repository.delete(params[:id])
        head :no_content
      end

      private

      def repository
        @repository ||= Infrastructure::Persistence::Repositories::PartsInActiveRecord.new
      end

      def part_params
        params.require(:part).permit(
          :sku, :description, :unit_price, :quantity_on_hand, :minimum_stock
        )
      end

      def unit_price_or(current)
        return current unless part_params.key?(:unit_price)

        Domain::Shared::Money.from_amount(part_params[:unit_price])
      end

      def serialize(part)
        {
          id: part.id,
          sku: part.sku,
          description: part.description,
          unit_price: part.unit_price.amount.to_s("F"),
          quantity_on_hand: part.quantity_on_hand,
          quantity_reserved: part.quantity_reserved,
          available: part.available_quantity,
          minimum_stock: part.minimum_stock,
          below_minimum: part.below_minimum?
        }
      end
    end
  end
end
