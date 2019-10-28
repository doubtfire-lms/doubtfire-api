require 'grape'

module Api
  class TutorialEnrolmentsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Enrol project in a tutorial'
    params do
      requires :project_id,  type: Integer,  desc: 'The id of the project to enrol'
    end
    post '/tutorials/:tutorial_id/enrolments' do
      tutorial = Tutorial.find(params[:tutorial_id])
      unless authorise? current_user, tutorial.unit, :enrol_student
        error!({ error: 'Not authorised to enrol student' }, 403)
      end

      project = Project.find(params[:project_id])
      result = tutorial.add_enrolment(project)

      if result.nil?
        error!({ error: 'No enrolment added' }, 403)
      else
        result
      end
    end
  end
end