require 'grape'

class StaffNotesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc "Get all the staff notes for a project"
  params do
    requires :project_id, type: Integer, desc: 'Project to fetch staff notes for'
  end
  get '/projects/:project_id/staff_notes' do
    project = Project.find(params[:project_id])

    unless authorise? current_user, project, :get_staff_note
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    result = project.staff_notes

    present result, with: Entities::StaffNoteEntity, user: current_user
  end

  desc "Create a new staff note for a project"
  params do
    requires :project_id,   type: Integer, desc: 'Project to add the staff note for'
    requires :note,         type: String, desc: 'The text to add to the staff note'
    optional :reply_to_id,  type: Integer, desc: 'ID of the staff note this is being replied to'
  end
  post '/projects/:project_id/staff_notes' do
    project = Project.find(params[:project_id])

    unless authorise? current_user, project, :create_staff_note
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    text_note = params[:note]

    reply_to_id = params[:reply_to_id]
    if reply_to_id.present?
      original_staff_note = StaffNote.find(reply_to_id)
      error!(error: 'You do not have permission to read the replied staff note') unless authorise?(current_user, original_staff_note.project, :get)
      error!(error: 'Original staff note is not in this project.') if project.staff_notes.find(reply_to_id).blank?
    end

    result = project.add_staff_note(current_user, text_note, reply_to_id)

    present result, with: Entities::StaffNoteEntity, user: current_user
  end

  desc "Delete a staff note for a project"
  delete '/projects/:project_id/staff_notes/:id' do
    project = Project.find(params[:project_id])
    staff_note = StaffNote.find(params[:id])

    unless authorise?(current_user, project, :delete_staff_note) || staff_note.user.id == current_user.id
      error!({ error: 'You do not have permission to delete this note.' }, 403)
    end

    error!({ error: 'Note does not belong to this project' }, 404) if staff_note.project_id != project.id

    staff_note.destroy
    error!({ error: staff_note.errors.full_messages.last }, 403) unless staff_note.destroyed?

    present staff_note.destroyed?, with: Grape::Presenters::Presenter
  end

  desc "Update a staff note for a project"
  params do
    requires :id, type: Integer, desc: 'The staff note id to update'
    requires :note, type: String, desc: 'The text to update the staff note with'
  end
  put '/projects/:project_id/staff_notes/:id' do
    project = Project.find(params[:project_id])
    staff_note = StaffNote.find(params[:id])

    unless authorise?(current_user, project, :create_staff_note) && staff_note.user.id == current_user.id
      error!({ error: 'You do not have permission to edit this note.' }, 403)
    end

    error!({ error: 'Note does not belong to this project' }, 404) if staff_note.project_id != project.id

    staff_note.update!(note: params[:note])
    present staff_note, with: Entities::StaffNoteEntity, user: current_user
  end

end
