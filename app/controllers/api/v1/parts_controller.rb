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

        render_page(parts, total, with: PartPresenter)
      end

      def show
        render_found(repository.find(params[:id]), with: PartPresenter, missing: "part")
      end

      def create
        result = container.register_part.call(
          sku: part_params[:sku],
          description: part_params[:description],
          unit_price: part_params[:unit_price],
          quantity_on_hand: part_params.fetch(:quantity_on_hand, 0),
          minimum_stock: part_params.fetch(:minimum_stock, 0)
        )

        respond_with(result, with: PartPresenter, success: :created)
      end

      # `quantity_on_hand` is deliberately not among the changes passed on.
      def update
        result = container.revise_part.call(
          id: params[:id], **changes_from(part_params, :description, :unit_price, :minimum_stock)
        )

        respond_with(result, with: PartPresenter)
      end

      def restock
        result = container.restock_part.call(id: params[:id], quantity: params[:quantity])

        respond_with(result, with: PartPresenter)
      end

      def destroy
        respond_with(container.remove_part.call(id: params[:id]), success: :no_content)
      end

      private

      def repository = container.parts

      def part_params
        params.require(:part).permit(
          :sku, :description, :unit_price, :quantity_on_hand, :minimum_stock
        )
      end
    end
  end
end
