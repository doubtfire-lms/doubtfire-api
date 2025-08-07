module LtiHelper
  def decode_lti_token(token)
    begin
      secret_key = Doubtfire::Application.config.lti_api_secret
      response = JWT.decode(token, secret_key, true, algorithm: 'HS256').first
      # TODO: cache our tokens JWT ID (jit) to prevent replay attacks
    rescue JWT::DecodeError => e
      logger.debug "Failed to validate Lti Token: #{e}"
      return error!({ error: 'Invalid LTI token.' }, 401)
    end
    response
  end
end
