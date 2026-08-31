module Infrastructure
  module Persistence
    module Records
      class User < BaseRecord
        self.table_name = "users"

        # The only place in the system that ever sees a plaintext password.
        # The domain only knows the digest.
        has_secure_password :password, validations: false
      end
    end
  end
end
