class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # private

  # rescue_from CanCan::AccessDenied do |exception|
  #   redirect_to root_url, alert:  exception.message
  # end

  private

  def send_download(path, filename:, type:)
    # The file-serving proxy sets this to "file-server" when it serves a
    # download itself, so the header says which tier streamed the bytes.
    response.headers['X-OnTrack-Served-By'] = 'rails'

    send_file path, type: type, disposition: 'attachment', filename: filename
  end
end
