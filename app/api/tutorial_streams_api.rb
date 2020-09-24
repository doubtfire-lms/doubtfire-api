require 'grape'

module Api
  class TutorialStreamsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Add a tutorial stream to the unit'
    params do
      requires :activity_type_abbr, type: String,   desc: 'Abbreviation of the activity type'
    end
    post '/units/:unit_id/tutorial_streams' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to add tutorial stream to this unit' }, 403)
      end

      activity_type = ActivityType.find_by(abbreviation: params[:activity_type_abbr])
      institution_settings = Doubtfire::Application.config.institution_settings

      name,abbreviation = institution_settings.details_for_next_tutorial_stream(unit, activity_type)

      unit.add_tutorial_stream(name, abbreviation, activity_type)
    end

    desc 'Update a tutorial stream in the unit'
    params do
      optional :name,               type: String,   desc: 'The name of the tutorial stream'
      optional :abbreviation,       type: String,   desc: 'The abbreviation for the tutorial stream'
      optional :activity_type_abbr, type: String,   desc: 'Abbreviation of the activity type'
    end
    put '/units/:unit_id/tutorial_streams/:tutorial_stream_abbr' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to update tutorial stream in this unit' }, 403)
      end

      tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: params[:tutorial_stream_abbr])
      activity_type = ActivityType.find_by!(abbreviation: params[:activity_type_abbr]) if params[:activity_type_abbr].present?
      unit.update_tutorial_stream(tutorial_stream, params[:name], params[:abbreviation], activity_type)
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
end