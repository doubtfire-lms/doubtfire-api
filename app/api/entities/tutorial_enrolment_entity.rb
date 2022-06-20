module Entities
  class TutorialEnrolmentEntity < Grape::Entity
    expose :project_id
    expose :tutorial_id
  end
end
