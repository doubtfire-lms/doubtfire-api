
module Entities
  class UserEntity < Grape::Entity
    expose :id
    expose :student_id
    expose :email
    expose :name
    expose :first_name
    expose :last_name
    expose :username
    expose :nickname
    expose :receive_task_notifications
    expose :receive_portfolio_notifications
    expose :receive_feedback_notifications
    expose :opt_in_to_research
    expose :has_run_first_time_setup

    expose :system_role do |user, options|
      user.role.name if user.role.present?
    end
  end
end
