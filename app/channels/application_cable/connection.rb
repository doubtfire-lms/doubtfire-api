module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected

    def find_verified_user
      if verified_user = env['warden'].user || user_from_token
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def user_from_token
      username = request.params[:username]
      auth_token = request.params[:authToken] || request.params[:auth_token] || request.params[:Auth_Token]
      return if username.blank? || auth_token.blank?

      user = User.eager_load(:role, :auth_tokens).find_by(username: username)
      token = user&.token_for_text?(auth_token, :general)
      return if token.blank?

      if token.auth_token_expiry > Time.zone.now
        user
      else
        token.destroy!
        nil
      end
    end
  end
end
