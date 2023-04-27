module Tii
  module Entities
    class TiiGroupAttachmentEntity < Grape::Entity
      expose :id
      expose :group_attachment_id
      expose :filename
      expose :status
    end
  end
end
