module Entities
  class TaskDefinitionEntity < Grape::Entity
    format_with(:date_only) do |date|
      date.strftime('%Y-%m-%d')
    end

    expose :id
    expose :abbreviation
    expose :name
    expose :description
    expose :weighting
    expose :target_grade

    with_options(format_with: :date_only) do
      expose :target_date
      expose :due_date
      expose :start_date
    end

    expose :upload_requirements
    expose :tutorial_stream_abbr do |tutorial, options|
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
