
# class UserSerializer < ActiveModel::Serializer
#   attributes :id, :student_id, :email, :name, :first_name, :last_name, :username, :nickname, :system_role, :receive_task_notifications, :receive_portfolio_notifications, :receive_feedback_notifications, :opt_in_to_research, :has_run_first_time_setup

#   def system_role
#     object.object.role.name if object.object.role
#   end
# end

# class ShallowUserSerializer < ActiveModel::Serializer
#   attributes :id, :name, :email, :student_id
# end

# class ShallowTutorSerializer < ActiveModel::Serializer
#   attributes :id, :name, :email
# end


module Api
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
end

