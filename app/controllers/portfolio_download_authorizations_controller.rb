class PortfolioDownloadAuthorizationsController < NativeDownloadAuthorizationsController
  native_download :portfolio,
                  uri: %r{\A/api/submission/unit/(?<unit_id>\d+)/portfolio(?:\?.*)?\z}

  private

  def download_ids
    { unit_id: params[:id] }
  end

  def locate_download(user, unit_id:)
    unit = Unit.find_by(id: unit_id)
    return :not_found unless unit
    return :forbidden unless authorise?(user, unit, :get_students)

    {
      path: unit.get_portfolio_zip_filename(user),
      filename: timestamped_download_name('portfolios', unit.code, user.username, extension: 'zip'),
      content_type: 'application/zip',
      disposition: 'attachment'
    }
  end
end
