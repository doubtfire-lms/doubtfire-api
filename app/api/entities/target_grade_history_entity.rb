module Entities
  class TargetGradeHistoryEntity < Grape::Entity
    expose :previous_grade
    expose :new_grade
    expose :changed_at
    expose :changed_by, using: Entities::Minimal::MinimalUserEntity
  end
end
