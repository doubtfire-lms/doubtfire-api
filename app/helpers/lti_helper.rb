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
      return error!({ error: 'Invalid LTI token.' }, 403)
    rescue StandardError => e
      logger.debug "Missing token properties: #{e}"
      return error!({ error: 'Invalid LTI token.' }, 403)
    end
    response
  end

  # Checks the connecting address, not request.ip, which trusts X-Forwarded-For from any private address
  def ensure_lti_service_request!
    remote_addr = request.env['REMOTE_ADDR']
    return if LtiServiceAddresses.allowed?(remote_addr)

    logger.warn "Rejected LTI service request from #{remote_addr}; it is not listed in LTI_SERVICE_HOSTS"
    error!({ error: 'Only the LTI service can make this request.' }, 403)
  end

  # Rejects a token whose LMS launch user is not the signed-in OnTrack user
  def ensure_lti_launch_user!(token)
    launch_email = token['email'].to_s.strip
    return if launch_email.present? && current_user.email.to_s.casecmp?(launch_email)

    logger.warn "Rejected LTI request for #{current_user.username} from #{request.ip}: not the launch user"
    error!({ error: 'This OnTrack session does not belong to the LMS user who launched OnTrack. Relaunch OnTrack from the LMS.' }, 403)
  end

  def valid_lti_member?(member)
    required_fields = %w[user_id email roles given_name family_name name]
    missing = required_fields.select { |f| member[f].nil? || member[f].to_s.strip.empty? }
    [missing.empty?, missing]
  end
end
