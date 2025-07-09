module Entities
  class StaffNoteEntity < Grape::Entity
    expose :id

    expose :note

    expose :author do |data, _options|
      {
        id: data.user_id,
        first_name: data.user.first_name,
        last_name: data.user.last_name,
        email: data.user.email
      }
    end

    expose :project
    expose :project_id

    expose :created_at
    expose :updated_at

    expose :reply_to_id

  end
end
