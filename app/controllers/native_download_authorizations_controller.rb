# Base class for bulk downloads the browser fetches natively.
#
# POST .../access authenticates with the Auth-Token header and mints a
# short-lived, path-scoped cookie. Caddy then calls #show for the download
# itself, which accepts either that cookie or the header.
#
# Subclasses declare their cookie kind and the URI they answer for, then
# implement #download_ids and #locate_download.
class NativeDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include DownloadAuthorization
  include NativeDownloadCookie

  # API authentication for :create comes from the Auth-Token header, which a
  # cross-origin form cannot forge.
  skip_forgery_protection only: :create

  class_attribute :download_kind, :download_uri, instance_writer: false

  def self.native_download(kind, uri:)
    self.download_kind = kind
    self.download_uri = uri
  end

  def show
    return head :not_found unless trusted_caddy_request?

    route_params = download_uri.match(original_uri)
    return head :not_found unless route_params

    ids = canonical_ids(route_params.named_captures.symbolize_keys)
    user = native_download_user(download_kind, **ids)
    return head :unauthorized unless user

    respond_with_download(user, ids)
  end

  def create
    user = download_header_user
    return head :unauthorized unless user

    ids = canonical_ids(download_ids)
    download = locate_download(user, **ids)
    return head download unless download.is_a?(Hash)
    return head :not_found unless authorised_file_path(download[:path]).first

    issue_native_download_cookie(download_kind, user: user, **ids)
    head :no_content
  end

  private

  def respond_with_download(user, ids)
    download = locate_download(user, **ids)
    return head download unless download.is_a?(Hash)

    _resolved, relative_path = authorised_file_path(download[:path])
    return head :not_found unless relative_path

    serve_via_caddy(relative_path: relative_path, **download.except(:path))
  end

  # Every id here is a numeric primary key. Normalising keeps the cookie's path
  # and payload identical whichever route the ids arrived through.
  def canonical_ids(ids)
    ids.transform_values(&:to_i)
  end

  # Map this controller's route params to the download's ids.
  def download_ids
    raise NotImplementedError
  end

  # Return { path:, filename:, content_type:, disposition: } for an authorised
  # request, or a status symbol (:not_found, :forbidden) to refuse it.
  def locate_download(_user, **_ids)
    raise NotImplementedError
  end
end
