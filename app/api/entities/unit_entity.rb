# class ShallowUnitSerializer < DoubtfireSerializer
#   attributes :code, :id, :name, :teaching_period_id, :start_date, :end_date, :active
# end

# class UnitSerializer < DoubtfireSerializer
#   attributes :code, :id, :name, :my_role, :main_convenor_id, :description, :teaching_period_id, :start_date, :end_date, :active, :convenors, :ilos, :auto_apply_extension_before_deadline, :send_notifications, :enable_sync_enrolments, :enable_sync_timetable, :group_memberships, :draft_task_definition_id, :allow_student_extension_requests, :extension_weeks_on_resubmit_request, :allow_student_change_tutorial

#   def start_date
#     object.start_date.to_date
#   end

#   def end_date
#     object.end_date.to_date
#   end

#   def my_role_obj
#     object.role_for(Thread.current[:user]) if Thread.current[:user]
#   end

#   def my_user_role
#     Thread.current[:user].role if Thread.current[:user]
#   end

#   def role
#     role = my_role_obj
#     role.name unless role.nil?
#   end

#   def my_role
#     role
#   end

#   def ilos
#     object.learning_outcomes
#   end

#   def main_convenor_id
#     object.main_convenor.id
#   end

#   has_many :tutorial_streams
#   has_many :tutorials
#   has_many :tutorial_enrolments
#   has_many :task_definitions
#   has_many :convenors, serializer: UserUnitRoleSerializer
#   has_many :staff, serializer: UserUnitRoleSerializer
#   has_many :group_sets, serializer: GroupSetSerializer
#   has_many :ilos, serializer: LearningOutcomeSerializer
#   has_many :task_outcome_alignments, serializer: LearningOutcomeTaskLinkSerializer
#   has_many :groups, serializer: GroupSerializer
  
#   def group_memberships
#     ActiveModel::ArraySerializer.new(object.group_memberships.where(active: true), each_serializer: GroupMembershipSerializer)
#   end

#   def include_convenors?
#     ([ Role.convenor, :convenor ].include? my_role_obj) || (my_user_role == Role.admin)
#   end

#   def include_staff?
#     ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj) || (my_user_role == Role.admin)
#   end

#   def include_groups?
#     ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj) || (my_user_role == Role.admin)
#   end

#   def include_enrolments?
#     ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj) || (my_user_role == Role.admin)
#   end

#   def filter(keys)
#     keys.delete :groups unless include_groups?
#     keys.delete :convenors unless include_convenors?
#     keys.delete :staff unless include_staff?
#     keys.delete :tutorial_enrolments unless include_enrolments?
#     keys
#   end
# end


module Api
  module Entities
    class UnitEntity < Grape::Entity
      expose :code
      expose :id
      expose :name
      expose :my_role do |unit, options|
        unit.role_for(options[:user])
      end
      expose :main_convenor_id
      expose :description
      expose :teaching_period_id
      expose :start_date
      expose :end_date
      expose :active
      expose :convenors
      expose :ilos do |unit, options|
        Api::Entities::LearningOutcomeEntity.represent object.learning_outcomes, options
      end
      expose :auto_apply_extension_before_deadline
      expose :send_notifications
      expose :enable_sync_enrolments
      expose :enable_sync_timetable
      expose :group_memberships
      expose :draft_task_definition_id
      expose :allow_student_extension_requests
      expose :extension_weeks_on_resubmit_request
      expose :allow_student_change_tutorial

      expose :tutorial_streams, using: TutorialStreamEntity
    end
  end
end