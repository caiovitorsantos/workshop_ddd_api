module Infrastructure
  module Auth
    # Issues and verifies the JWTs that protect the administrative APIs.
    #
    # This lives in Infrastructure because JWT is a technical detail: the domain
    # knows "User" and "role", not "Bearer token". Swapping JWT for a session or
    # an external OAuth provider must not touch a single business rule.
    module JwtToken
      ALGORITHM = "HS256".freeze
      LIFETIME  = 8.hours

      Expired = Class.new(StandardError)
      Invalid = Class.new(StandardError)

      module_function

      def issue(user, now: Time.current)
        JWT.encode(
          {
            sub: user.id,
            role: user.role.to_s,
            iat: now.to_i,
            exp: (now + LIFETIME).to_i
          },
          secret,
          ALGORITHM
        )
      end

      # Returns the payload or raises — never a silent `nil`, so a tampered
      # token cannot turn into "authorized anonymous user".
      def verify(token)
        payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM, verify_expiration: true)
        payload
      rescue JWT::ExpiredSignature
        raise Expired, "expired token"
      rescue JWT::DecodeError => e
        raise Invalid, "invalid token: #{e.message}"
      end

      def expires_in = LIFETIME.to_i

      # Development and test fall back to Rails' secret_key_base; production
      # demands an explicit JWT_SECRET, so the token signing key is not the same
      # key that protects the whole application's encrypted credentials.
      def secret
        key = ENV["JWT_SECRET"].presence
        return key if key

        raise KeyError, "set JWT_SECRET in the production environment" if Rails.env.production?

        Rails.application.secret_key_base
      end
    end
  end
end
