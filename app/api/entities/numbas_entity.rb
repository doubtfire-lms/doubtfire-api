
module Entities
  class NumbasEntity < Grape::Entity
    expose :file_content, documentation: { type: 'string', desc: 'File content' }
    expose :content_type, documentation: { type: 'string', desc: 'Content type' }
  end
end
