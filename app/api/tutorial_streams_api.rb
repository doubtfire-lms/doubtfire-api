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
      requires :name,              type: String,  desc: 'The name of the tutorial stream'
      requires :abbreviation,      type: String,  desc: 'The abbreviation for the tutorial stream'
      optional :combine_all_tasks, type: Boolean,  desc: 'Special property that defines whether tutorial stream combines all tasks'
    end
    post '/units/:unit_id/:activity_type_abbr/tutorial_streams' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :add_tutorial
        error!({ error: 'Not authorised to add tutorial stream to this unit' }, 403)
      end

      activity_type = ActivityType.find_by(abbreviation: params[:activity_type_abbr])
      tutorial_stream = unit.add_tutorial_stream(params[:name], params[:abbreviation], activity_type, params[:combine_all_tasks])

      if tutorial_stream.nil?
        error!({ error: 'No tutorial stream added' }, 403)
      else
        tutorial_stream
      end
    end
  end
end