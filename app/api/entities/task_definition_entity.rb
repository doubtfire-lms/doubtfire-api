module Entities
  class TaskDefinitionEntity < Grape::Entity
    format_with(:date_only) do |date|
      date.strftime('%Y-%m-%d')
    end

    def staff?(my_role)
      Role.teaching_staff_ids.include?(my_role.id) unless my_role.nil?
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

    expose :upload_requirements do |task_definition, options|
      if staff?(options[:my_role])
        task_definition.upload_requirements
      else
        # Filter out turn it in details
        task_definition.upload_requirements.map { |r| r.except('tii_check', 'tii_pct') }
      end
    end

    expose :tutorial_stream_abbr do |task_definition, options|
      task_definition.tutorial_stream.abbreviation unless task_definition.tutorial_stream.nil?
    end
    expose :plagiarism_warn_pct, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :restrict_status_updates, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :group_set_id
    expose :has_task_sheet?, as: :has_task_sheet
    expose :has_task_resources?, as: :has_task_resources
    expose :has_task_assessment_resources?, as: :has_task_assessment_resources, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :is_graded
    expose :max_quality_pts
    expose :overseer_image_id, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :assessment_enabled, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :moss_language, if: ->(unit, options) { staff?(options[:my_role]) }
  end
end
