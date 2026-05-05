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
  end
end
