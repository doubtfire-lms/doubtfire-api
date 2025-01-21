module Entities
  class ProjectEntity < Grape::Entity
    expose :id
    expose :campus_id
    expose :student, using: Entities::Minimal::MinimalUserEntity, unless: :for_student
    expose :user_id, if: :for_student
    expose :unit, if: ->(status, options) { options[:for_student] || options[:summary_only] }, using: Entities::Minimal::MinimalUnitEntity
    expose :unit_id, if: :for_student, unless: :summary_only

    expose :enrolled, unless: :for_student
    expose :target_grade

    expose :submitted_grade, unless: :summary_only
    expose :portfolio_files, unless: :summary_only
    expose :compile_portfolio, unless: :summary_only
    expose :portfolio_available
    expose :uses_draft_learning_summary, unless: :summary_only

    expose :task_stats, as: :stats, unless: :for_student

    expose :tasks, using: TaskEntity, unless: :summary_only do |project, options|
      project.task_details_for_shallow_serializer(options[:user])
    end

    expose :tutorial_enrolments, using: TutorialEnrolmentEntity, unless: :summary_only
    expose :groups, using: GroupEntity, unless: :summary_only
    expose :task_outcome_alignments, using: TaskOutcomeAlignmentEntity, unless: :summary_only

    expose :grade, if: :for_staff
    expose :grade_rationale, if: :for_staff

    expose :target_grade_histories, using: Entities::TargetGradeHistoryEntity, if: ->(project, options) { options[:in_project] }
  end
end
