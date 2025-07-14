module Entities
  class StaffNoteEntity < Grape::Entity
    expose :id

    expose :note
    expose :user_id

    expose :created_at
    expose :updated_at

    expose :reply_to_id

  end
end
