module Entities
  class TestAttemptEntity < Grape::Entity
    expose :id, :name, :attempt_number, :pass_status, :exam_data, :completed, :cmi_entry
    expose :task_id, as: :associated_task_id
    expose :exam_result, :attempted_at
  end
end
