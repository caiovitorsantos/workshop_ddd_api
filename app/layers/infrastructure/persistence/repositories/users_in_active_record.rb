module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord adapter for the Domain::Identity::UserRepository port.
      class UsersInActiveRecord < Domain::Identity::UserRepository
        Record = Records::User

        def save(user, password: nil)
          record = user.new_record? ? Record.new : Record.find(user.id)

          record.assign_attributes(
            name: user.name, email: user.email,
            role: user.role.to_s, active: user.active?
          )

          # Only Infrastructure ever handles the plaintext password; what goes
          # up to the domain is the digest.
          if password.present?
            record.password = password
          else
            record.password_digest = user.password_digest
          end
          record.save!

          to_domain(record)
        end

        def find(id)
          record = Record.find_by(id: id)
          record && to_domain(record)
        end

        def find_by_email(email)
          record = Record.find_by(email: email.to_s.downcase)
          record && to_domain(record)
        end

        # Password check: constant-time BCrypt comparison, done here because
        # `password_digest` is an infrastructure detail.
        def valid_credentials?(email, password)
          record = Record.find_by(email: email.to_s.downcase)
          return false unless record&.active?

          record.authenticate_password(password.to_s).present?
        end

        private

        def to_domain(record)
          Domain::Identity::User.new(
            id: record.id, name: record.name, email: record.email,
            role: record.role, password_digest: record.password_digest, active: record.active
          )
        end
      end
    end
  end
end
