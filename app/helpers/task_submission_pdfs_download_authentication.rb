module TaskSubmissionPdfsDownloadAuthentication
  TASK_SUBMISSION_PDFS_DOWNLOAD_COOKIE = 'ontrack_task_submission_pdfs_download'.freeze
  TASK_SUBMISSION_PDFS_DOWNLOAD_TICKET_SCOPE = 'task-submission-pdfs'.freeze
  TASK_SUBMISSION_PDFS_DOWNLOAD_TICKET_ENV_KEY = 'ontrack.task_submission_pdfs_download_ticket_nonce'.freeze
  TASK_SUBMISSION_PDFS_DOWNLOAD_COOKIE_LIFETIME = 30.seconds

  private

  def authenticated_task_submission_pdfs_download_user(unit_id:, task_definition_id:)
    authenticated_task_submission_pdfs_header_user || task_submission_pdfs_download_cookie_user(
      unit_id: unit_id,
      task_definition_id: task_definition_id
    )
  end

  def authenticated_task_submission_pdfs_header_user
    username, token = get_user_and_token_from(:header)
    return unless username.present? && token.present?
    return unless user_auth_token_type(username, token, :general) == :valid

    current_user
  end

  def task_submission_pdfs_download_cookie_user(unit_id:, task_definition_id:)
    payload = JSON.parse(cookies.encrypted[TASK_SUBMISSION_PDFS_DOWNLOAD_COOKIE].to_s)
    return unless payload['unit_id'].to_s == unit_id.to_s
    return unless payload['task_definition_id'].to_s == task_definition_id.to_s
    return unless payload['expires_at'].to_i > Time.current.to_i

    nonce = payload['nonce'].presence
    return unless nonce

    request.env[TASK_SUBMISSION_PDFS_DOWNLOAD_TICKET_ENV_KEY] = nonce

    User.find_by(id: payload['user_id'])
  rescue JSON::ParserError
    nil
  end

  def consume_task_submission_pdfs_download_ticket!(unit_id:, task_definition_id:)
    original_method = request.headers['X-Forwarded-Method'].presence || request.request_method
    return true if original_method == 'HEAD'
    nonce = request.env[TASK_SUBMISSION_PDFS_DOWNLOAD_TICKET_ENV_KEY]
    return true unless nonce

    cookies.delete(
      TASK_SUBMISSION_PDFS_DOWNLOAD_COOKIE,
      domain: Doubtfire::Application.config.institution[:cookie_domain],
      path: "/api/submission/unit/#{unit_id}/task_definitions/#{task_definition_id}/student_pdfs",
      secure: request.ssl? || Rails.env.production?,
      httponly: true,
      same_site: :strict
    )
    OneTimeDownloadTicket.consume(
      scope: TASK_SUBMISSION_PDFS_DOWNLOAD_TICKET_SCOPE,
      nonce: nonce
    )
  end
end
