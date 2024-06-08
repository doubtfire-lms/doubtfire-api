module Entities
  class UnitEntity < Grape::Entity
    format_with(:date_only) do |date|
      date.strftime('%Y-%m-%d')
    end

    def is_staff?(my_role)
      [Role.tutor_id, Role.convenor_id, Role.admin_id, Role.auditor_id].include?(my_role.id) unless my_role.nil?
    end

    def can_read_unit_config?(my_role)
      [Role.convenor_id, Role.admin_id, Role.auditor_id].include?(my_role.id) unless my_role.nil?
    end

    expose :code
    expose :id
    expose :name
    expose :my_role do |unit, options|
      role = options[:my_role]
      role = unit.role_for(options[:user]) if role.nil?
      role.name unless role.nil?
    end
    expose :main_convenor_id, unless: :summary_only
    expose :main_convenor_user_id, if: :summary_only do |unit, options|
      unit.main_convenor.user_id
    end

    expose :description
    expose :teaching_period_id, expose_nil: false

    with_options(format_with: :date_only) do
      expose :start_date
      expose :end_date
      expose :portfolio_auto_generation_date, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }, expose_nil: false
    end

    expose :active

    expose :overseer_image_id, unless: :summary_only, if: lambda { |unit, options| can_read_unit_config?(options[:my_role]) }
    expose :assessment_enabled, unless: :summary_only

    expose :auto_apply_extension_before_deadline, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }
    expose :send_notifications, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }
    expose :enable_sync_enrolments, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }
    expose :enable_sync_timetable, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }
    expose :draft_task_definition_id, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }
    expose :allow_student_extension_requests, unless: :summary_only
    expose :extension_weeks_on_resubmit_request, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }
    expose :allow_student_change_tutorial, unless: :summary_only

    expose :learning_outcomes, using: LearningOutcomeEntity, as: :ilos, unless: :summary_only
    expose :tutorial_streams, using: TutorialStreamEntity, unless: :summary_only
    expose :tutorials, using: TutorialEntity, unless: :summary_only
    # expose :tutorial_enrolments, using: TutorialEnrolmentEntity, unless: :summary_only, if: lambda { |unit, options| is_staff?(options[:my_role]) }

    expose :ordered_task_definitions, as: :task_definitions, using: TaskDefinitionEntity, unless: :summary_only
    expose :task_outcome_alignments, using: TaskOutcomeAlignmentEntity, unless: :summary_only
    expose :staff, using: UnitRoleEntity, unless: :summary_only
    expose :group_sets, using: GroupSetEntity, unless: :summary_only
    expose :groups, using: GroupEntity, unless: :summary_only
    # expose :group_memberships, using: GroupMembershipEntity, unless: :summary_only do |unit, options|
    #   unit.group_memberships.where(active: true)
    # end
  end
end
