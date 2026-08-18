module Entities
  class CommunicationActionEntity < Grape::Entity
    expose :id
    expose :type
    expose :communication_rule_id
    expose :subject
    expose :body
    expose :email_tutors
    expose :email_convenors
    expose :target_grade
    expose :task_definition_id
    expose :unresolved_references
    expose :unresolved?, as: :unresolved
    expose :unresolved_summary
  end
end
