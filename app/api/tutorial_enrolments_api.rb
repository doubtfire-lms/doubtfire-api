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

    desc 'Get all the enrolments in the tutorial'
    get '/tutorials/:tutorial_id/enrolments' do
      tutorial = Tutorial.find(params[:tutorial_id])
      unless authorise? current_user, tutorial.unit, :get_students
        error!({ error: 'Not authorised to get enrolments for the selected tutorial' }, 403)
      end

      tutorial.tutorial_enrolments
    end

    desc 'Get specific enrolment in the tutorial'
    get '/tutorials/:tutorial_id/enrolments/:id' do
      tutorial = Tutorial.find(params[:tutorial_id])
      unless authorise? current_user, tutorial.unit, :get_students
        error!({ error: 'Not authorised to get enrolments for the selected tutorial' }, 403)
      end

      tutorial.tutorial_enrolments.find(params[:id])
    end

    desc 'Delete an enrolment in the tutorial'
    delete '/tutorials/:tutorial_id/enrolments/:id' do
      tutorial = Tutorial.find(params[:tutorial_id])
      unless authorise? current_user, tutorial.unit, :enrol_student
        error!({ error: 'Not authorised to delete tutorial enrolments' }, 403)
      end

      tutorial.tutorial_enrolments.find(params[:id]).destroy
    end
  end
end