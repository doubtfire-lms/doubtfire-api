# class TaskDefinitionSerializer < DoubtfireSerializer
#   attributes :id, :abbreviation, :name, :description,
#              :weight, :target_grade, :target_date,
#              :upload_requirements,
#              :tutorial_stream,
#              :plagiarism_checks, :plagiarism_report_url, :plagiarism_warn_pct,
#              :restrict_status_updates,
#              :group_set_id, :has_task_sheet?, :has_task_resources?,
#              :due_date, :start_date, :is_graded, :max_quality_pts

#   def weight
#     object.weighting
#   end

#   def tutorial_stream
#     object.tutorial_stream.abbreviation unless object.tutorial_stream.nil?
#   end
# end

module Api
  module Entities
    class TaskDefinitionEntity < Grape::Entity
      format_with(:date_only) do |date|
        date.strftime('%Y-%m-%d')
      end

      expose :id
      expose :abbreviation
      expose :name
      expose :description
      expose :weighting, as: :weight
      expose :target_grade

      with_options(format_with: :date_only) do
        expose :target_date
        expose :due_date
        expose :start_date
      end

      expose :upload_requirements
      expose :tutorial_stream do |tutorial, options|
        tutorial.tutorial_stream.abbreviation unless tutorial.tutorial_stream.nil?
      end
      expose :plagiarism_checks
      expose :plagiarism_report_url
      expose :plagiarism_warn_pct
      expose :restrict_status_updates
      expose :group_set_id
      expose :has_task_sheet?, as: :has_task_sheet
      expose :has_task_resources?, as: :has_task_resources
      expose :has_task_assessment_resources?, as: :has_task_assessment_resources
      expose :is_graded
      expose :max_quality_pts
      expose :overseer_image_id
      expose :assessment_enabled
    end
  end
end
