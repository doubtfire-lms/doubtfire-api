module LtiHelper
  # The LTI service signs tokens that expire after 30 seconds
  LTI_TOKEN_MAX_LIFETIME = 60

  # Records a token id, returning false if it was already used. One SET NX, so concurrent replays can't both pass
  def self.first_use?(jti, ttl)
    Sidekiq.redis { |redis| redis.call('SET', "lti:jti:#{jti}", '1', 'NX', 'EX', ttl) } == 'OK'
  end

  # Verifies a token the LTI service signed for this purpose, and rejects one that was already used
  def decode_lti_token(token, purpose:)
    begin
      secret_key = Doubtfire::Application.config.lti_api_secret
      response = JWT.decode(token, secret_key, true, algorithm: 'HS256').first

      jti = response['jti']
      exp = response['exp']

      raise "Missing jti" if jti.nil?
      raise "Missing exp" if exp.nil?
      raise "Expires more than #{LTI_TOKEN_MAX_LIFETIME}s ahead" if exp.to_i > Time.now.to_i + LTI_TOKEN_MAX_LIFETIME
      raise "Signed for #{response['purpose'].inspect}, not #{purpose}" unless response['purpose'] == purpose
    rescue JWT::DecodeError => e
      logger.debug "Failed to validate Lti Token: #{e}"
      return error!({ error: 'Invalid LTI token.' }, 403)
    rescue StandardError => e
      logger.debug "Invalid token properties: #{e}"
      return error!({ error: 'Invalid LTI token.' }, 403)
    end

    # Kept a little past expiry, after which JWT.decode rejects the token anyway
    unless LtiHelper.first_use?(jti, exp.to_i - Time.now.to_i + 5)
      logger.warn "Rejected a replayed LTI token from #{request.ip}"
      error!({ error: 'Invalid LTI token.' }, 403)
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
