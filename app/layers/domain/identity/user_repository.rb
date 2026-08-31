module Domain
  module Identity
    # Port for the User aggregate repository.
    class UserRepository
      def save(user)            = not_implemented
      def find(id)              = not_implemented
      def find_by_email(email)  = not_implemented

      private

      def not_implemented
        raise NotImplementedError, "#{self.class} does not implement this repository method"
      end
    end
  end
end
