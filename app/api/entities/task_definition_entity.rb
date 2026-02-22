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
      # expose :p_target_date, expose_nil: false
      expose :c_target_date, expose_nil: false
      expose :d_target_date, expose_nil: false
      expose :hd_target_date, expose_nil: false
    end

    expose :upload_requirements, expose_nil: false do |task_definition, options|
      if staff?(options[:my_role])
        task_definition.upload_requirements
      else
        # Filter out turn it in details
        task_definition.upload_requirements.map { |r| r.except('tii_check', 'tii_pct') } unless task_definition.upload_requirements.nil?
      end
    end

    expose :tutorial_stream_abbr do |task_definition, options|
      task_definition.tutorial_stream.abbreviation unless task_definition.tutorial_stream.nil?
    end
    expose :plagiarism_warn_pct, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :restrict_status_updates, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :group_set_id, expose_nil: false
    expose :has_task_sheet?, as: :has_task_sheet
    expose :has_task_resources?, as: :has_task_resources
    expose :has_task_assessment_resources?, as: :has_task_assessment_resources, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :has_task_assessment_script?, as: :has_task_assessment_script, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :has_scorm_data?, as: :has_scorm_data
    expose :scorm_enabled
    expose :scorm_allow_review
    expose :scorm_bypass_test
    expose :scorm_time_delay_enabled
    expose :scorm_attempt_limit
    expose :has_jplag_report?, as: :has_jplag_report, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :is_graded
    expose :max_quality_pts
    expose :overseer_image_id, if: ->(unit, options) { staff?(options[:my_role]) }, expose_nil: false
    # expose :assessment_enabled, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :assessment_enabled
    expose :similarity_language, if: ->(unit, options) { staff?(options[:my_role]) }, expose_nil: false
    expose :assess_in_portfolio_only
    expose :use_resources_for_jplag_base_code, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :lock_assessments_to_tutorial_stream, if: ->(unit, options) { staff?(options[:my_role]) }

    expose :learning_outcomes, using: LearningOutcomeEntity, as: :ilos

    expose :discussion_prompts_count do |task_def|
      task_def.discussion_prompts.size
    end

    # expose :overseer_steps, using: OverseerStepEntity, if: ->(unit, options) { staff?(options[:my_role]) }
    expose :overseer_steps, using: OverseerStepEntity do |task_def, options|
      task_def.overseer_steps # options[:my_role] is still available inside the entity
    end
    expose :overseer_resource_files, if: ->(task_def, options) { staff?(options[:my_role]) }

  end
end
