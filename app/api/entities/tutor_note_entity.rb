module Entities
  class TutorNoteEntity < Grape::Entity
    expose :id

    expose :note
    expose :unit_role_id
    expose :user_id

    expose :created_at
    expose :updated_at

    expose :reply_to_id

    # TODO: what is tutor_notes_id?

  end
end
