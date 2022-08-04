module Entities
  class ProjectEntity < Grape::Entity
    expose :unit_id
    expose :id, as: :project_id
    expose :student_id do |project, options|
      project.student.username
    end
    expose :campus_id
    expose :student_name do |project, options|
      "#{project.student.name}#{project.student.nickname.blank? ? '' : ' (' << project.student.nickname << ')'}"
    end
    expose :enrolled
    expose :target_grade
    expose :submitted_grade
    expose :portfolio_files
    expose :compile_portfolio
    expose :portfolio_available
    expose :uses_draft_learning_summary

    expose :task_stats, as: :stats
    expose :burndown_chart_data

    expose :tasks do |project, options|
      project.task_details_for_shallow_serializer(options[:user])
    end
    expose :tutorial_enrolments, using: TutorialEnrolmentEntity
    expose :groups, using: GroupEntity
    expose :task_outcome_alignments, using: TaskOutcomeAlignmentEntity

    expose :grade, if: :for_staff
    expose :grade_rationale, if: :for_staff
  end
end
