class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # private

  # rescue_from CanCan::AccessDenied do |exception|
  #   redirect_to root_url, alert:  exception.message
  # end

  # AuthenticationHelpers is written for Grape, where #headers means the request
  # headers, so controllers including it need the same meaning here.
  delegate :headers, to: :request

  private

  # send_file writes its Content-Disposition through #headers, which the
  # delegate above sends to the request instead of the response - so the browser
  # would receive no filename and name the download after the URL's last
  # segment. Set the response header ourselves and tell send_file to skip it.
  def send_download(path, filename:, type:)
    response.headers['Content-Disposition'] = ActionDispatch::Http::ContentDisposition.format(
      disposition: 'attachment',
      filename: filename
    )

    # The file-serving proxy sets this to "file-server" when it serves a
    # download itself, so the header says which tier streamed the bytes.
    response.headers['X-OnTrack-Served-By'] = 'rails'

    send_file path, type: type, disposition: nil
  end
end
