module Api
  module V1
    # POST /api/v1/session — exchanges email + password for a JWT.
    class SessionsController < BaseController
      skip_authentication only: :create

      def create
        repository = Infrastructure::Persistence::Repositories::UsersInActiveRecord.new

        # One single message for any bad credential: we never reveal whether the
        # email exists, which is what stops user enumeration.
        unless repository.valid_credentials?(params[:email], params[:password])
          return render_error("invalid credentials", :unauthorized)
        end

        user = repository.find_by_email(params[:email])

        render json: {
          token: Infrastructure::Auth::JwtToken.issue(user),
          expires_in: Infrastructure::Auth::JwtToken.expires_in,
          user: { id: user.id, name: user.name, role: user.role }
        }, status: :created
      end
    end
  end
end
