require 'grape'

module Api
  class TutorialEnrolmentsApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Enrol project in a tutorial'
    post '/units/:unit_id/tutorials/:tutorial_abbr/enrolments/:project_id' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :enrol_student
        error!({ error: 'Not authorised to enrol student' }, 403)
      end

      tutorial = unit.tutorials.find_by(abbreviation: params[:tutorial_abbr])
      error!({ error: "No tutorial with abbreviation #{params[:tutorial_abbr]} exists for the unit" }, 403) unless tutorial.present?

      project = Project.find(params[:project_id])
      result = project.enrol_in(tutorial)

      if result.nil?
        error!({ error: 'No enrolment added' }, 403)
      else
        result
      end
    end

    desc 'Delete an enrolment in the tutorial'
    delete '/units/:unit_id/tutorials/:tutorial_abbr/enrolments/:project_id' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :enrol_student
        error!({ error: 'Not authorised to delete tutorial enrolments' }, 403)
      end

      tutorial = unit.tutorials.find_by(abbreviation: params[:tutorial_abbr])
      error!({ error: "No tutorial with abbreviation #{params[:tutorial_abbr]} exists for the unit" }, 403) unless tutorial.present?

      tutorial_enrolment = tutorial.tutorial_enrolments.find_by(project_id: params[:project_id])
      error!({ error: "Project not enrolled in the selected tutorial" }, 403) unless tutorial_enrolment.present?
      tutorial_enrolment.destroy
    end
  end
end