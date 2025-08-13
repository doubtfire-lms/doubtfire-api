module LtiHelper
  def decode_lti_token(token)
    begin
      secret_key = Doubtfire::Application.config.lti_api_secret
      response = JWT.decode(token, secret_key, true, algorithm: 'HS256').first

      jti = response['jti']
      exp = response['exp']

      raise "Missing jti" if jti.nil?
      raise "Missing exp" if exp.nil?
    rescue JWT::DecodeError => e
      logger.debug "Failed to validate Lti Token: #{e}"
      return error!({ error: 'Invalid LTI token.' }, 401)
    rescue StandardError => e
      logger.debug "Missing token properties: #{e}"
      return error!({ error: 'Invalid LTI token.' }, 401)
    end
    response
  end
end
