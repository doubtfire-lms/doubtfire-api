module Entities
  class TutorNoteEntity < Grape::Entity
    expose :id

    expose :note
    expose :unit_role_id
    expose :user_id

    expose :created_at
    expose :updated_at

    expose :reply_to_id

    expose :task_id
    expose :task_definition_id
    expose :project_id

    expose :read_by_unit_role

    expose :requires_current_user_read do |tutor_note, options|
      tutor_note.requires_read_by?(options[:user])
    end
  end
end
