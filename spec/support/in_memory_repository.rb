# An in-memory adapter for any repository port.
#
#   repo = in_memory(Domain::Registry::CustomerRepository)
#   use_case = Application::Registry::UpdateCustomerContact.new(customers: repo)
#
# It subclasses the real port, so a method the use case calls but the port
# does not declare still fails loudly, and anything the double does not
# implement raises the port's own NotImplementedError. That it fits in a few
# lines is the practical payoff of the use cases depending on abstractions.
module InMemoryRepository
  def self.for(port)
    Class.new(port) do
      def initialize
        @rows = {}
        @sequence = 0
      end

      def save(entity)
        entity.instance_variable_set(:@id, @sequence += 1) if entity.id.nil?
        @rows[entity.id] = entity
      end

      def find(id) = @rows[id.to_i]
      def find_for_update(id) = find(id)
      def delete(id) = @rows.delete(id.to_i)
      def all = @rows.values
    end.new
  end

  module Helpers
    def in_memory(port) = InMemoryRepository.for(port)
  end
end

RSpec.configure do |config|
  config.include InMemoryRepository::Helpers
end
