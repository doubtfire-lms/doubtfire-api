require 'grape'

class TutorNotesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  helpers do
    def can_access_tutor_notes?(unit, current_user, unit_role)
      current_user_role = unit.unit_role_for(current_user)

      current_user_role.role == Role.convenor ||
        unit_role.mentor_id == current_user_role.id ||
        unit_role == current_user_role
    end
  end

  desc "Get all the tutor notes for a unit role"
  params do
    requires :unit_role_id, type: Integer, desc: 'Unit role to fetch the notes for'
  end
  get '/unit_roles/:unit_role_id/tutor_notes' do
    unit_role = UnitRole.find(params[:unit_role_id])
    unit = unit_role.unit
    unless authorise? current_user, unit, :get_unit
      error!({ error: 'You do not have permission to access this unit' }, 403)
    end

    unless authorise? current_user, unit_role, :create_tutor_note
      error!({ error: 'You do not have permission to access this.' }, 403)
    end

    unless can_access_tutor_notes?(unit, current_user, unit_role)
      error!({ error: 'You do not have permission to access this.' }, 403)
    end

    result = unit_role.tutor_notes.includes(:notifications)

    present result, with: Entities::TutorNoteEntity, user: current_user
  end

  desc "Mark a tutor note as read"
  params do
    requires :unit_role_id, type: Integer, desc: 'Unit role to fetch the notes for'
  end
  put '/unit_roles/:unit_role_id/tutor_notes/:id/mark_as_read' do
    unit_role = UnitRole.find(params[:unit_role_id])

    unit = unit_role.unit
    unless authorise? current_user, unit, :get_unit
      error!({ error: 'You do not have permission to access this unit' }, 403)
    end

    unless can_access_tutor_notes?(unit, current_user, unit_role)
      error!({ error: 'You do not have permission to access this.' }, 403)
    end

    tutor_note = unit_role.tutor_notes.find(params[:id])

    note_is_about_me = unit.unit_role_for(current_user) == unit_role

    unless note_is_about_me || tutor_note.notification_for(current_user).present?
      error!({ error: 'You do not have permission to update this note.' }, 403)
    end

    TutorNote.transaction do
      tutor_note.update!(read_by_unit_role: true) if note_is_about_me
      Notification.mark_tutor_note_read(current_user, tutor_note)
    end

    true
  end

  desc "Create a new note for a tutor"
  params do
    requires :note,         type: String, desc: 'The text to add to the tutor note'
    optional :reply_to_id,  type: Integer, desc: 'ID of the tutor note this is being replied to'
    optional :task_id,      type: Integer, desc: 'ID of the task this note is related to'
  end
  post '/unit_roles/:unit_role_id/tutor_notes' do
    unit_role = UnitRole.find(params[:unit_role_id])
    unit = unit_role.unit
    unless authorise? current_user, unit, :get_unit
      error!({ error: 'You do not have permission to access this unit.' }, 403)
    end

    unless authorise? current_user, unit_role, :create_tutor_note
      error!({ error: 'You do not have permission to create note.' }, 403)
    end

    unless can_access_tutor_notes?(unit, current_user, unit_role)
      error!({ error: 'You do not have permission to create note.' }, 403)
    end

    text_note = params[:note]

    reply_to_id = params[:reply_to_id]
    if reply_to_id.present?
      original_staff_note = TutorNote.find(reply_to_id)
      error!(error: 'You do not have permission to read the replied tutor note') unless authorise?(current_user, original_staff_note.unit_role, :get)
      error!(error: 'Original tutor note is not in this project.') if unit_role.tutor_notes.find(reply_to_id).blank?
    end

    task_id = params[:task_id]
    if task_id.present?
      task = Task.find(task_id)
      error!(error: 'You do not have permission to add a note related to this task') unless authorise?(unit_role.user, task.project, :assess)
    end

    current_unit_role = unit.unit_role_for(current_user)

    result = unit_role.add_tutor_note(current_user, text_note, task_id, reply_to_id)

    reply_target = original_staff_note && unit.unit_role_for(original_staff_note.user)

    notify_unit_role, notification_kind =
      if reply_target && original_staff_note.user != current_user
        # tutor is responding to a reply -> notify original user that tutor is replying to
        [reply_target, 'moderation_note_reply']
      elsif current_unit_role == unit_role
        # tutor is writing on their own notes -> notify the mentor
        [unit_role.mentor, 'moderation_note_from_mentee']
      else
        # anyone else wrote about this tutor, whether its their mentor or another convenor -> notify tutor
        [unit_role, 'moderation_note_added']
      end

    if result.present? && notify_unit_role.present? && notify_unit_role.user_id != current_user.id
      begin
        NotifyTutorNotesJob.perform_async(result.id, notify_unit_role.user.id, notification_kind)
      rescue StandardError => e
        Rails.logger.error("Failed to send tutor note email for TutorNote #{result.id}: #{e.class} - #{e.message}")
      end
    end

    if result.nil?
      error!({ error: 'Duplicate note.' }, 403)
    else
      present result, with: Entities::TutorNoteEntity, user: current_user
    end
  end

  desc "Delete a tutor note for a unit role"
  delete '/unit_roles/:unit_role_id/tutor_notes/:id' do
    unit_role = UnitRole.find(params[:unit_role_id])
    unit = unit_role.unit
    unless authorise? current_user, unit, :get_unit
      error!({ error: 'You do not have permission to access this unit' }, 403)
    end

    unless can_access_tutor_notes?(unit, current_user, unit_role)
      error!({ error: 'You do not have permission to access create note.' }, 403)
    end

    tutor_note = unit_role.tutor_notes.find(params[:id])

    error!({ error: 'Note does not belong to this tutor' }, 404) if tutor_note.unit_role != unit_role

    unless authorise?(current_user, unit_role, :delete_tutor_note) || tutor_note.user.id == current_user.id
      error!({ error: 'You do not have permission to delete this note.' }, 403)
    end

    tutor_note.destroy
    error!({ error: tutor_note.errors.full_messages.last }, 403) unless tutor_note.destroyed?

    present tutor_note.destroyed?, with: Grape::Presenters::Presenter
  end

  desc "Update a tutor note for a project"
  params do
    requires :unit_role_id, type: Integer, desc: 'The ID of the unit role'
    requires :id, type: Integer, desc: 'The tutor note id to update'
    requires :note, type: String, desc: 'The text to update the tutor note with'
  end
  put '/unit_roles/:unit_role_id/tutor_notes/:id' do
    unit_role = UnitRole.find(params[:unit_role_id])
    unit = unit_role.unit
    unless authorise? current_user, unit, :get_unit
      error!({ error: 'You do not have permission to access this unit' }, 403)
    end

    unless authorise? current_user, unit_role, :create_tutor_note
      error!({ error: 'You do not have permission to access this.' }, 403)
    end

    tutor_note = unit_role.tutor_notes.find(params[:id])

    unless can_access_tutor_notes?(unit, current_user, unit_role)
      error!({ error: 'You do not have permission to access create note.' }, 403)
    end

    error!({ error: 'Note does not belong to this tutor' }, 404) if tutor_note.unit_role != unit_role

    unless tutor_note.user.id == current_user.id
      error!({ error: 'You do not have permission to delete this note.' }, 403)
    end

    tutor_note.update!(note: params[:note])
    present tutor_note, with: Entities::TutorNoteEntity, user: current_user
  end

end
