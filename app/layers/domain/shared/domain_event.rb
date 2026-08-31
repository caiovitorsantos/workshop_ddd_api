module Domain
  module Shared
    # Base of every domain event — one orange sticky from the Event Storming
    # board, made executable.
    #
    # Naming rule from the workshop: events are written in the **past tense**
    # (`QuoteApproved`), because an event is something that already happened.
    # Commands, which are what *cause* events, are imperative (`ApproveQuote`).
    # Keeping that distinction in the class names is what lets the board and the
    # code be read side by side.
    #
    # `aggregate_id` rather than `service_order_id`/`part_id`: the class name
    # already says which aggregate emitted it, and a shared shape is what lets
    # PublishesEvents work for every aggregate root.
    DomainEvent = Struct.new(:aggregate_id, :occurred_at, :payload, keyword_init: true) do
      # "QuoteApproved" -> "quote_approved". Handy for logs and for matching an
      # event against the sticky it came from.
      def name = self.class.name.demodulize.underscore
    end
  end
end
