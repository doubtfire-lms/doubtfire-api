require 'mime/types'
require 'pathname'
require 'rack/files'
require 'uri'

class UnitContentDownloadAuthorizationsController < ApplicationController
  include AuthorisationHelpers

  skip_after_action :verify_same_origin_request, only: :serve

  CONTENT_VERSION = '[0-9a-f]{64}'.freeze
  CONTENT_PATH = %r{\A/api/units/(?<unit_id>\d+)/content/sites/(?<site_id>\d+)/files(?:/v/(?<content_version>#{CONTENT_VERSION}))?(?<route>/[^?]*)?(?:\?.*)?\z}
  VERSIONED_ROUTE = %r{\Av/(?<content_version>#{CONTENT_VERSION})(?<route>/.*)?\z}
  VERSIONED_CACHE_CONTROL = 'private, max-age=604800, immutable'.freeze
  LEGACY_CACHE_CONTROL = 'private, no-cache'.freeze
  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze

  def show
    return head :not_found unless trusted_caddy_request?

    route_params = CONTENT_PATH.match(request.headers[ORIGINAL_URI_HEADER].to_s)
    return head :not_found unless route_params

    result = authorised_content(
      unit_id: route_params[:unit_id],
      site_id: route_params[:site_id],
      route: route_params[:route],
      content_version: route_params[:content_version]
    )
    return head result unless result.is_a?(Hash)

    content_type = content_type_for(result[:path])
    disposition = ActionDispatch::Http::ContentDisposition.format(
      disposition: 'inline',
      filename: result[:path].basename.to_s
    )

    response.set_header('X-OnTrack-File', result[:relative_path])
    response.set_header('X-OnTrack-Content-Disposition', disposition)
    response.set_header('X-OnTrack-Content-Type', content_type)
    response.set_header('X-OnTrack-Cache-Control', result[:cache_control])
    head :ok
  end

  def serve
    route, content_version = route_and_version(params[:route])
    result = authorised_content(
      unit_id: params[:unit_id],
      site_id: params[:site_id],
      route: route,
      content_version: content_version
    )
    return head result unless result.is_a?(Hash)

    disposition = ActionDispatch::Http::ContentDisposition.format(
      disposition: 'inline',
      filename: result[:path].basename.to_s
    )
    file_server = Rack::Files.new(
      nil,
      {
        'accept-ranges' => 'bytes',
        'cache-control' => result[:cache_control],
        'content-disposition' => disposition
      },
      content_type_for(result[:path])
    )
    file_status, file_headers, file_body = file_server.serving(request, result[:path].to_s)
    self.status = file_status
    file_headers.each { |name, value| response.set_header(name, value) }
    self.response_body = file_body
  end

  private

  def trusted_caddy_request?
    expected = Doubtfire::Application.config.caddy_download_auth_secret.to_s
    provided = request.headers[INTERNAL_SECRET_HEADER].to_s
    expected.present? && provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def authenticated_content_user
    username = request.cookies['username'].to_s
    token_text = request.cookies[AuthenticationHelpers::CONTENT_TOKEN_COOKIE].to_s
    return nil if username.blank? || token_text.blank?

    user = User.eager_load(:role).find_by(username: username)
    return nil unless user

    token = user.auth_tokens.where(token_type: :content).detect do |candidate|
      ActiveSupport::SecurityUtils.secure_compare(candidate.authentication_token, token_text)
    end
    return nil unless token

    if token.auth_token_expiry <= Time.zone.now
      token.destroy!
      return nil
    end

    user
  end

  def authorised_content(unit_id:, site_id:, route:, content_version: nil)
    user = authenticated_content_user
    return :unauthorized unless user

    unit = Unit.find_by(id: unit_id)
    return :not_found unless unit
    return :forbidden unless authorise?(user, unit, :get_unit) || authorise?(user, User, :admin_units)

    site = unit.unit_content_sites.find_by(id: site_id)
    return :not_found unless site
    return :not_found if content_version.present? && !valid_content_version?(site, content_version)

    file_path = site.served_file_path(route.presence || '/')
    resolved_path, relative_path = authorised_file_path(file_path, site.served_dir)
    return :not_found unless resolved_path

    {
      path: resolved_path,
      relative_path: relative_path,
      cache_control: content_version.present? ? VERSIONED_CACHE_CONTROL : LEGACY_CACHE_CONTROL
    }
  end

  def route_and_version(route)
    match = VERSIONED_ROUTE.match(route.to_s)
    return [route, nil] unless match

    [match[:route], match[:content_version]]
  end

  def valid_content_version?(site, content_version)
    ActiveSupport::SecurityUtils.secure_compare(site.content_version, content_version)
  end

  def content_type_for(path)
    MIME::Types.type_for(path.to_s).first&.content_type || 'application/octet-stream'
  end

  def authorised_file_path(file_path, site_root)
    return [nil, nil] if file_path.blank? || !File.file?(file_path)

    student_work_root = Pathname.new(Doubtfire::Application.config.student_work_dir).realpath
    root = Pathname.new(site_root).realpath
    resolved = Pathname.new(file_path).realpath
    return [nil, nil] unless resolved.to_s.start_with?("#{root}#{File::SEPARATOR}")
    return [nil, nil] unless resolved.to_s.start_with?("#{student_work_root}#{File::SEPARATOR}")

    [resolved, resolved.relative_path_from(student_work_root).to_s]
  rescue Errno::ENOENT, Errno::EACCES
    [nil, nil]
  end
end
