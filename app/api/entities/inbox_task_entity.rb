module Entities
  class InboxTaskEntity < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :unit_id, documentation: { type: Integer }
    expose :project_id, documentation: { type: Integer }
    expose :task_definition_id, documentation: { type: Integer }
    expose :tutorial_id, documentation: { type: Integer, required: false, nullable: true }

    expose :status, documentation: { type: String }

    expose :completion_date, documentation: { type: DateTime, required: false, nullable: true }
    expose :submission_date, documentation: { type: DateTime, required: false, nullable: true }

    expose :times_assessed, documentation: { type: Integer, required: false, nullable: true }
    expose :grade, documentation: { type: String, required: false, nullable: true }
    expose :quality_pts, documentation: { type: Float, required: false, nullable: true }

    expose :num_new_comments, documentation: { type: Integer }
    expose :similarity_flag, documentation: { type: 'boolean' }
    expose :pinned, documentation: { type: 'boolean' }
    expose :has_extensions, documentation: { type: 'boolean' }
  end
end
