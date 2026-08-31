# Requires a valid JWT on the administrative APIs.
#
# Phase 1 requirement: "JWT authentication for the administrative APIs". The
# customer's public order-tracking endpoint is the explicit exception — it calls
# `skip_authentication`, so that "open to the public" is always a declared
# decision and never an oversight.
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    attr_reader :current_user
  end

  class_methods do
    def skip_authentication(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    payload = Infrastructure::Auth::JwtToken.verify(bearer_token)
    @current_user = user_repository.find(payload["sub"])

    return if @current_user&.may_administer?

    render json: { error: "user lacks administrative permission" }, status: :forbidden
  rescue Infrastructure::Auth::JwtToken::Expired,
         Infrastructure::Auth::JwtToken::Invalid => e
    render json: { error: e.message }, status: :unauthorized
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header[/\ABearer (.+)\z/, 1].to_s
  end

  def user_repository
    Infrastructure::Persistence::Repositories::UsersInActiveRecord.new
  end
end
