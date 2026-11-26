require 'pathname'

# Shared plumbing for the endpoints Caddy calls before serving a protected file.
# Caddy forwards the browser's original request here; on success we return the
# file's student-work-relative path in X-OnTrack-* headers and Caddy serves it
# straight from disk.
module DownloadAuthorization
  extend ActiveSupport::Concern

  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze

  private

  def trusted_caddy_request?
    expected = Doubtfire::Application.config.caddy_download_auth_secret.to_s
    provided = request.headers[INTERNAL_SECRET_HEADER].to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def original_uri
    request.headers[ORIGINAL_URI_HEADER].to_s
  end

  def download_header_user
    username, token = get_user_and_token_from(:header)
    return unless username.present? && token.present?
    return unless user_auth_token_type(username, token, :general) == :valid

    current_user
  end

  # Confine file_path to the student work directory, and optionally to a
  # narrower root within it. Returns [absolute, student-work-relative] or nils.
  def authorised_file_path(file_path, within: nil)
    return [nil, nil] if file_path.blank? || !File.file?(file_path)

    root = Pathname.new(Doubtfire::Application.config.student_work_dir).realpath
    resolved = Pathname.new(file_path).realpath
    return [nil, nil] unless path_contained?(resolved, root)
    return [nil, nil] if within.present? && !path_contained?(resolved, Pathname.new(within).realpath)

    [resolved, resolved.relative_path_from(root).to_s]
  rescue Errno::ENOENT, Errno::EACCES
    [nil, nil]
  end

  def path_contained?(resolved, root)
    resolved.to_s.start_with?("#{root}#{File::SEPARATOR}")
  end

  def serve_via_caddy(relative_path:, filename:, content_type:, disposition:, cache_control: nil)
    content_disposition = ActionDispatch::Http::ContentDisposition.format(
      disposition: disposition,
      filename: filename
    )

    response.set_header('X-OnTrack-File', url_encoded_path(relative_path))
    response.set_header('X-OnTrack-Content-Disposition', content_disposition)
    response.set_header('X-OnTrack-Content-Type', content_type)
    response.set_header('X-OnTrack-Cache-Control', cache_control) if cache_control.present?
    head :ok
  end

  # Caddy rewrites the request to this path, so it is parsed as a URL. Encode
  # each segment or a '?' truncates the path and a '%' decodes to another file.
  def url_encoded_path(relative_path)
    relative_path.to_s.split('/').map { |segment| ERB::Util.url_encode(segment) }.join('/')
  end

  def attachment_requested?(query)
    ActiveModel::Type::Boolean.new.cast(Rack::Utils.parse_nested_query(query.to_s)['as_attachment'])
  end

  # e.g. "2026-09-14 13:47:22-portfolios-COS10011-alice.zip"
  def timestamped_download_name(*parts, extension:)
    name = [Time.zone.now.strftime('%Y-%m-%d %H:%M:%S'), *parts].join('-')
    "#{FileHelper.sanitized_filename(name.tr('\\/', '-'))}.#{extension}"
  end
end
