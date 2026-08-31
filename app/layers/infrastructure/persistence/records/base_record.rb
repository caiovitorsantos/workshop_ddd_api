module Infrastructure
  module Persistence
    module Records
      # Base class for the ActiveRecord models.
      #
      # These are deliberately dumb: they are *tables*, not entities. No
      # business rule lives here — that is app/layers/domain. They exist so the
      # repositories can read and write rows, and nothing below this boundary
      # crosses out of the Infrastructure layer.
      class BaseRecord < ActiveRecord::Base
        self.abstract_class = true
      end
    end
  end
end
