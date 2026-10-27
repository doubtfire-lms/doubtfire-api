module Entities
  class StaffNoteEntity < Grape::Entity
    expose :id

    expose :note
    expose :user_id

    expose :created_at
    expose :updated_at

    expose :reply_to_id
    expose :attachment_type
    expose :has_attachment do |note, _options|
      note.attachment?
    end

  end
end
