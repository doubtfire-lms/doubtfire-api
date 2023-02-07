require 'grape'
require 'icalendar'

class WebcalPublicApi < Grape::API
  # Declare content types
  content_type :txt, 'text/calendar'

  desc 'Serve webcal with the specified GUID'
  params do
    requires :guid, type: String, desc: 'The GUID of the webcal'
  end
  get '/webcal/:guid' do
    # Retrieve the specified webcal.
    webcal = Webcal.find_by!(guid: params[:guid])

    # Serve the iCalendar with the correct MIME type.
    content_type 'text/calendar'

    # Seve ical.
    present webcal.to_ical.to_ical
  end
end
