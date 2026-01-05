module Entities
  class OverseerStepEntity < Grape::Entity
    expose :id
    expose :task_definition_id

    def staff?(my_role)
      Role.teaching_staff_ids.include?(my_role.id) unless my_role.nil?
    end

    expose :name, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :description, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :display_name
    expose :display_description

    expose :run_command, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :timeout, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :sort_order, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :step_type
    expose :partial_output_diff, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :stdin_input_file, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :expected_output_file, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :feedback_message, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :status_on_success,
           if: ->(_obj, options) { staff?(options[:my_role]) } do |overseer_step|
      TaskStatus.find_by(id: overseer_step.status_on_success_id)&.status_key || 'no_change'
    end

    expose :status_on_failure,
           if: ->(_obj, options) { staff?(options[:my_role]) } do |overseer_step|
      TaskStatus.find_by(id: overseer_step.status_on_failure_id)&.status_key || 'no_change'
    end

    expose :halt_on_success, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :halt_on_failure, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :show_expected_output, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :show_stdin, if: ->(_unit, options) { staff?(options[:my_role]) }
    expose :show_stdout, if: ->(_unit, options) { staff?(options[:my_role]) }

    expose :enabled
  end
end
