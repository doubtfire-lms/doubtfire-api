require 'grape'

class TutorialStreamsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers

  before do
    authenticated?
  end

  desc 'Add a tutorial stream to the unit'
  params do
    requires :activity_type_abbr, type: String, desc: 'Abbreviation of the activity type'
  end
  post '/units/:unit_id/tutorial_streams' do
    unit = Unit.find(params[:unit_id])
    unless authorise? current_user, unit, :add_tutorial
      error!({ error: 'Not authorised to add tutorial stream to this unit' }, 403)
    end

    activity_type = ActivityType.find_by(abbreviation: params[:activity_type_abbr])
    institution_settings = Doubtfire::Application.config.institution_settings

    name, abbreviation = institution_settings.details_for_next_tutorial_stream(unit, activity_type)

    unit.add_tutorial_stream(name, abbreviation, activity_type)
  end

  desc 'Update a tutorial stream in the unit'
  params do
    optional :name,               type: String,   desc: 'The name of the tutorial stream'
    optional :abbreviation,       type: String,   desc: 'The abbreviation for the tutorial stream'
    optional :activity_type, type: String, desc: 'Abbreviation of the activity type'
  end
  put '/units/:unit_id/tutorial_streams/:tutorial_stream_abbr' do
    unit = Unit.find(params[:unit_id])
    unless authorise? current_user, unit, :add_tutorial
      error!({ error: 'Not authorised to update tutorial stream in this unit' }, 403)
    end

    tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: params[:tutorial_stream_abbr])
    activity_type = ActivityType.find_by!(abbreviation: params[:activity_type]) if params[:activity_type].present?
    present unit.update_tutorial_stream(tutorial_stream, params[:name], params[:abbreviation], activity_type), with: Entities::TutorialStreamEntity
  end

  desc 'Download CSV of all tutorial streams for the given unit'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to download tutorial streams from'
  end
  get '/units/:unit_id/tutorial_streams/csv' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :download_unit_csv
      error!({ error: 'Not authorised to download CSV of tutorial streams' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-TutorialStreams.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    unit.tutorial_streams_csv
  end

  desc 'Upload CSV of tutorial streams to the given unit'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to upload tutorial streams to'
    requires :file, type: File, desc: 'CSV upload file.'
  end
  post '/units/:unit_id/tutorial_streams/csv' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :upload_csv
      error!({ error: 'Not authorised to upload CSV of tutorial streams' }, 403)
    end

    if params[:file].blank?
      error!({ error: 'No file uploaded' }, 403)
    end

    # check mime is correct before uploading
    ensure_csv!(params[:file][:tempfile])

    present unit.import_tutorial_streams_from_csv(params[:file][:tempfile]), with: Grape::Presenters::Presenter
  end

  desc 'Delete a tutorial stream in the unit'
  delete '/units/:unit_id/tutorial_streams/:tutorial_stream_abbr' do
    unit = Unit.find(params[:unit_id])
    unless authorise? current_user, unit, :add_tutorial
      error!({ error: 'Not authorised to delete tutorial stream in this unit' }, 403)
    end

    tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: params[:tutorial_stream_abbr])
    tutorial_stream.destroy
    error!({ error: tutorial_stream.errors.full_messages.last }, 403) unless tutorial_stream.destroyed?
    tutorial_stream.destroyed?
  end
end
