require 'pathname'

class PortfolioDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers

  # API authentication for this action is supplied by the Auth-Token header.
  # A cross-origin form cannot forge that custom header.
  skip_forgery_protection only: :create

  DOWNLOAD_PATH = %r{\A/api/submission/unit/(?<unit_id>\d+)/portfolio(?:\?.*)?\z}
  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze
  DOWNLOAD_COOKIE = 'ontrack_portfolio_download'.freeze
  DOWNLOAD_COOKIE_LIFETIME = 2.minutes

  def show
    return head :not_found unless trusted_caddy_request?

    route_params = DOWNLOAD_PATH.match(request.headers[ORIGINAL_URI_HEADER].to_s)
    return head :not_found unless route_params
    return head :unauthorized unless authenticate_download(route_params[:unit_id])

    unit = Unit.find_by(id: route_params[:unit_id])
    return head :not_found unless unit
    return head :forbidden unless authorise?(@download_user, unit, :get_students)

    _resolved_path, relative_path = authorised_file_path(unit.get_portfolio_zip_filename(@download_user))
    return head :not_found unless relative_path

    disposition = ActionDispatch::Http::ContentDisposition.format(
      disposition: 'attachment',
      filename: download_filename(unit)
    )

    response.set_header('X-OnTrack-File', relative_path)
    response.set_header('X-OnTrack-Content-Disposition', disposition)
    response.set_header('X-OnTrack-Content-Type', 'application/zip')

    head :ok
  end

  # Exchange the normal Auth-Token header for a very short-lived, HTTP-only
  # cookie. This allows the browser to start a native streaming download, which
  # cannot attach Angular's custom authentication headers.
  def create
    @download_user = authenticated_header_user
    return head :unauthorized unless @download_user

    unit = Unit.find_by(id: params[:id])
    return head :not_found unless unit
    return head :forbidden unless authorise?(@download_user, unit, :get_students)
    return head :not_found unless authorised_file_path(unit.get_portfolio_zip_filename(@download_user)).first

    expires_at = Time.current + DOWNLOAD_COOKIE_LIFETIME
    cookies.encrypted[DOWNLOAD_COOKIE] = {
      value: { user_id: @download_user.id, unit_id: unit.id, expires_at: expires_at.to_i }.to_json,
      expires: expires_at,
      domain: Doubtfire::Application.config.institution[:cookie_domain],
      path: "/api/submission/unit/#{unit.id}/portfolio",
      secure: request.ssl? || Rails.env.production?,
      httponly: true,
      same_site: :strict
    }

    head :no_content
  end

  private

  def trusted_caddy_request?
    expected = ENV.fetch('DF_CADDY_DOWNLOAD_AUTH_SECRET', '')
    provided = request.headers[INTERNAL_SECRET_HEADER].to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def authenticated_header_user
    username, token = get_user_and_token_from(:header)
    return unless user_auth_token_type(username, token, :general) == :valid

    current_user
  end

  def authenticate_download(unit_id)
    @download_user = authenticated_header_user
    return true if @download_user

    payload = JSON.parse(cookies.encrypted[DOWNLOAD_COOKIE].to_s)
    return false unless payload['unit_id'].to_s == unit_id.to_s
    return false unless payload['expires_at'].to_i > Time.current.to_i

    @download_user = User.find_by(id: payload['user_id'])
    @download_user.present?
  rescue JSON::ParserError
    false
  end

  def download_filename(unit)
    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%m:%S')}-portfolios-#{unit.code}-#{@download_user.username}"
    "#{FileHelper.sanitized_filename(download_id.tr('\\/', '-'))}.zip"
  end

  def authorised_file_path(file_path)
    return [nil, nil] if file_path.blank? || !File.file?(file_path)

    root = Pathname.new(Doubtfire::Application.config.student_work_dir).realpath
    resolved = Pathname.new(file_path).realpath
    root_prefix = "#{root}#{File::SEPARATOR}"
    return [nil, nil] unless resolved.to_s.start_with?(root_prefix)

    [resolved, resolved.relative_path_from(root).to_s]
  rescue Errno::ENOENT, Errno::EACCES
    [nil, nil]
  end
end
