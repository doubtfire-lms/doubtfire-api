module Api
  module Entities
    class TutorialEnrolmentEntity < Grape::Entity
      expose :id
      expose :project_id
      expose :tutorial_id
    end
  end
end
