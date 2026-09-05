require 'mime/types'
require 'pathname'
require 'rack/files'
require 'uri'

class UnitContentDownloadAuthorizationsController < ApplicationController
  include AuthorisationHelpers

  skip_after_action :verify_same_origin_request, only: :serve

  CONTENT_PATH = %r{\A/api/units/(?<unit_id>\d+)/content/sites/(?<site_id>\d+)/files(?<route>/[^?]*)?(?:\?.*)?\z}
  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze

  def show
    return head :not_found unless trusted_caddy_request?

    route_params = CONTENT_PATH.match(request.headers[ORIGINAL_URI_HEADER].to_s)
    return head :not_found unless route_params

    result = authorised_content(
      unit_id: route_params[:unit_id],
      site_id: route_params[:site_id],
      route: route_params[:route]
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
    response.set_header('X-OnTrack-Content-Site-Id', result[:site].id.to_s)
    head :ok
  end

  def serve
    result = authorised_content(
      unit_id: params[:unit_id],
      site_id: params[:site_id],
      route: params[:route]
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
        'cache-control' => 'private, no-cache',
        'content-disposition' => disposition,
        'x-content-site-id' => result[:site].id.to_s
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
    expected = ENV.fetch('DF_CADDY_DOWNLOAD_AUTH_SECRET', '')
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

  def authorised_content(unit_id:, site_id:, route:)
    user = authenticated_content_user
    return :unauthorized unless user

    unit = Unit.find_by(id: unit_id)
    return :not_found unless unit
    return :forbidden unless authorise?(user, unit, :get_unit) || authorise?(user, User, :admin_units)

    site = unit.unit_content_sites.find_by(id: site_id)
    return :not_found unless site

    file_path = site.served_file_path(route.presence || '/')
    resolved_path, relative_path = authorised_file_path(file_path, site.served_dir)
    return :not_found unless resolved_path

    { site: site, path: resolved_path, relative_path: relative_path }
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
