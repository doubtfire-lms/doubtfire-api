# Short-lived access cookies for downloads the browser fetches natively, by
# following a plain link, instead of through Angular's authenticated XHR.
#
# Each kind is scoped by path to the single URL it authorises, so a cookie
# issued for one unit or task definition is never offered anywhere else.
module NativeDownloadCookie
  extend ActiveSupport::Concern

  LIFETIME = 30.seconds

  KINDS = {
    portfolio: {
      cookie: 'ontrack_portfolio_download',
      url: ->(unit_id:) { "/api/submission/unit/#{unit_id}/portfolio" }
    },
    task_submission_files: {
      cookie: 'ontrack_task_submission_files_download',
      url: lambda { |unit_id:, task_definition_id:|
        "/api/submission/unit/#{unit_id}/task_definitions/#{task_definition_id}/download_submissions"
      }
    },
    task_submission_pdfs: {
      cookie: 'ontrack_task_submission_pdfs_download',
      url: lambda { |unit_id:, task_definition_id:|
        "/api/submission/unit/#{unit_id}/task_definitions/#{task_definition_id}/student_pdfs"
      }
    }
  }.freeze

  def self.cookie_name(kind)
    KINDS.fetch(kind)[:cookie]
  end

  def self.url_path(kind, **ids)
    KINDS.fetch(kind)[:url].call(**ids)
  end

  private

  def native_download_user(kind, **ids)
    download_header_user || native_download_cookie_user(kind, **ids)
  end

  def issue_native_download_cookie(kind, user:, **ids)
    expires_at = Time.current + LIFETIME

    cookies.encrypted[NativeDownloadCookie.cookie_name(kind)] = {
      value: { user_id: user.id, expires_at: expires_at.to_i, **ids }.to_json,
      expires: expires_at,
      domain: Doubtfire::Application.config.institution[:cookie_domain],
      path: NativeDownloadCookie.url_path(kind, **ids),
      secure: request.ssl? || Rails.env.production?,
      httponly: true,
      same_site: :strict
    }
  end

  # Valid for its whole lifetime, not single-use: browsers resume an interrupted
  # download by re-requesting the same URL.
  def native_download_cookie_user(kind, **ids)
    payload = JSON.parse(cookies.encrypted[NativeDownloadCookie.cookie_name(kind)].to_s)
    return if ids.empty?
    return unless ids.all? { |key, value| payload[key.to_s].to_s == value.to_s }
    return unless payload['expires_at'].to_i > Time.current.to_i

    User.find_by(id: payload['user_id'])
  rescue JSON::ParserError
    nil
  end
end
