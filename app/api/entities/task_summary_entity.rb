module Entities
  class TaskSummaryEntity < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :task_definition_id, documentation: { type: Integer }
    expose :status, documentation: { type: String }
    expose :tutorial_id, documentation: { type: Integer, required: false }
    expose :tutorial_stream_id, documentation: { type: Integer, required: false }
  end
end
