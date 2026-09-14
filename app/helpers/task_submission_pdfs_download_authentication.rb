module TaskSubmissionPdfsDownloadAuthentication
  TASK_SUBMISSION_PDFS_DOWNLOAD_COOKIE = 'ontrack_task_submission_pdfs_download'.freeze
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

    User.find_by(id: payload['user_id'])
  rescue JSON::ParserError
    nil
  end
end
