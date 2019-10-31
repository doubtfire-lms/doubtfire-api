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
      requires :name,              type: String,   desc: 'The name of the tutorial stream'
      requires :abbreviation,      type: String,   desc: 'The abbreviation for the tutorial stream'
      optional :combine_all_tasks, type: Boolean,  desc: 'Special property that defines whether tutorial stream combines all tasks'
    end
    post '/units/:unit_id/activity_types/:activity_type_abbr/tutorial_streams' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to add tutorial stream to this unit' }, 403)
      end

      activity_type = ActivityType.find_by!(abbreviation: params[:activity_type_abbr])
      tutorial_stream = unit.add_tutorial_stream(params[:name], params[:abbreviation], activity_type, params[:combine_all_tasks])

      if tutorial_stream.nil?
        error!({ error: 'No tutorial stream added' }, 403)
      else
        tutorial_stream
      end
    end

    desc 'Update a tutorial stream in the unit'
    params do
      optional :name,              type: String,   desc: 'The name of the tutorial stream'
      optional :abbreviation,      type: String,   desc: 'The abbreviation for the tutorial stream'
      optional :combine_all_tasks, type: Boolean,  desc: 'Special property that defines whether tutorial stream combines all tasks'
    end
    put '/units/:unit_id/activity_types/:activity_type_abbr/tutorial_streams/:tutorial_stream_abbr' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to update tutorial stream in this unit' }, 403)
      end

      tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: params[:tutorial_stream_abbr])
      activity_type = ActivityType.find_by!(abbreviation: params[:activity_type_abbr])
      error!({ error: "Tutorial stream with abbreviation #{params[:tutorial_stream_abbr]} does not exist for the activity type #{params[:activity_type_abbr]}" }, 403) unless tutorial_stream.activity_type.eql? activity_type

      unit.update_tutorial_stream(tutorial_stream, params[:name], params[:abbreviation], params[:combine_all_tasks])
    end

    desc 'Delete a tutorial stream in the unit'
    delete '/units/:unit_id/activity_types/:activity_type_abbr/tutorial_streams/:tutorial_stream_abbr' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to delete tutorial stream in this unit' }, 403)
      end

      tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: params[:tutorial_stream_abbr])
      activity_type = ActivityType.find_by!(abbreviation: params[:activity_type_abbr])
      error!({ error: "Tutorial stream with abbreviation #{params[:tutorial_stream_abbr]} does not exist for the activity type #{params[:activity_type_abbr]}" }, 403) unless tutorial_stream.activity_type.eql? activity_type
      tutorial_stream.destroy
    end
  end
end