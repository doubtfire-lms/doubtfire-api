module Entities
  class LearningOutcomeEntity < Grape::Entity
    expose :id
    expose :context_type
    expose :context_id
    expose :abbreviation
    expose :short_description
    expose :full_outcome_description

    #expose :feedback_template_chips, using: Feedback::FeedbackTemplateChipEntity, as: :template_chips
    #expose :feedback_group_chips, using: Feedback::FeedbackGroupChipEntity, as: :group_chips
  end
end
