module Api
  module Entities
    class ProjectEntity < Grape::Entity
      expose :unit_id
      expose :id, as: :project_id
      expose :student_id do |project, options|
        project.student.username
      end
      expose :campus_id
      expose :student_name do |project, options|
        "#{project.student.name}#{project.student.nickname.nil? ? '' : ' (' << project.student.nickname << ')'}"
      end
      expose :enrolled
      expose :target_grade
      expose :submitted_grade
      expose :portfolio_files
      expose :compile_portfolio
      expose :portfolio_available
      expose :uses_draft_learning_summary

      expose :grade, if: lambda { |project, options|
        ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? project.role_for(options[:user])) || (options[:user].role_id == Role.admin_id)
      }
      expose :grade_rationale, if: lambda { |project, options|
        ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? project.role_for(options[:user])) || (options[:user].role_id == Role.admin_id)
      }

      expose :task_stats, as: :stats
      expose :burndown_chart_data

      expose :tasks
      expose :tutorial_enrolments
      expose :groups
      expose :task_outcome_alignments
    end
  end
end
