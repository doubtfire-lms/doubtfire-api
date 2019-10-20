require 'grape'

module Api
  class EnrolmentsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Enrol student in an activity'
    params do
      requires :enrolment, type: Hash do
        requires :tutorial_id, type: Integer, desc: 'The id of the tutorial'
        requires :project_id,  type: Integer, desc: 'The id of the project'
      end
    end
    post '/enrolments' do
      enrolment_parameters = ActionController::Parameters.new(params)
                                                               .require(:enrolment)
                                                               .permit(:tutorial_id,
                                                                      :project_id)

      project_id = enrolment_parameters['project_id']
      project = Project.find(project_id)

      unless authorise? current_user, project, :enrol
        error!({ error: 'Not authorised to enrol student in tutorial' }, 403)
      end

      result = Enrolment.create!(enrolment_parameters)

      if result.nil?
        error!({ error: 'Failed to enrol' }, 403)
      else
        result
      end
    end
  end
end