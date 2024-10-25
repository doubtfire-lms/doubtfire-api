module Entities
  class TestAttemptEntity < Grape::Entity
    expose :id
    expose :task_id
    expose :attempted_time
    expose :terminated
    expose :success_status
    expose :score_scaled
    expose :completion_status
    expose :cmi_datamodel
  end
end
