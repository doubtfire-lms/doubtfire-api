require 'grape'

class TutorialEnrolmentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Enrol project in a tutorial'
  post '/units/:unit_id/tutorials/:tutorial_abbr/enrolments/:project_id' do
    unit = Unit.find(params[:unit_id])
    project = unit.active_projects.find(params[:project_id])
    unless authorise? current_user, project, :change_tutorial, ->(role, perm_hash, other) { project.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to change tutorial' }, 403)
    end

    tutorial = unit.tutorials.find_by(abbreviation: params[:tutorial_abbr])
    error!({ error: "No tutorial with abbreviation #{params[:tutorial_abbr]} exists for the unit" }, 403) if tutorial.blank?

    # If the tutorial has a capacity, and we are at that capacity, and the user does not have permissions to exceed capacity...
    if tutorial.capacity > 0 && tutorial.tutorial_enrolments.count >= tutorial.capacity && !authorise?(current_user, unit, :exceed_capacity)
      error!({ error: "Tutorial #{params[:tutorial_abbr]} is full and cannot accept further student enrolments" }, 403)
    end

    result = project.enrol_in(tutorial)

    if result.nil?
      error!({ error: 'No enrolment added' }, 403)
    else
      result
    end

    present :enrolments, project.tutorial_enrolments, with: Entities::TutorialEnrolmentEntity
  end

  desc 'Delete an enrolment in the tutorial'
  delete '/units/:unit_id/tutorials/:tutorial_abbr/enrolments/:project_id' do
    unit = Unit.find(params[:unit_id])
    project = unit.projects.find(params[:project_id])
    unless authorise? current_user, project, :change_tutorial, ->(role, perm_hash, other) { project.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to change tutorials' }, 403)
    end

    tutorial = unit.tutorials.find_by(abbreviation: params[:tutorial_abbr])
    error!({ error: "No tutorial with abbreviation #{params[:tutorial_abbr]} exists for the unit" }, 403) if tutorial.blank?

    tutorial_enrolment = tutorial.tutorial_enrolments.find_by(project_id: params[:project_id])
    error!({ error: "Project not enrolled in the selected tutorial" }, 403) if tutorial_enrolment.blank?
    tutorial_enrolment.destroy

    # present :enrolments, project.tutorial_enrolments, with: Entities::TutorialEnrolmentEntity
    present true, with: Grape::Presenters::Presenter
  end
end
