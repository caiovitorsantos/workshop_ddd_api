module Application
  module Workshop
    # Shared by the use cases that move a service order's parts in or out of
    # inventory — approval consumes them, rejection and cancellation release
    # them. All three need the quoted parts as `{ part_id => total_quantity }`,
    # locked in a stable order.
    #
    # Sorting is not cosmetic: two concurrent operations that lock the same two
    # parts in opposite orders deadlock. Always taking locks in ascending
    # part_id order means one transaction simply waits for the other.
    #
    # Grouping fixes a subtler bug: the same part can appear on two lines of one
    # order, and handling each line separately would check a balance that only
    # covers one.
    module QuotedPartQuantities
      private

      def quantities_by_part(order)
        order.part_items
             .group_by(&:part_id)
             .transform_values { |items| items.sum(&:quantity) }
             .sort_by { |part_id, _| part_id }
      end
    end
  end
end
