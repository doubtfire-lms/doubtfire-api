module Entities
  class OverseerStepEntity < Grape::Entity
    expose :id
    expose :task_definition_id

    expose :name
    expose :description

    expose :display_name
    expose :display_description

    expose :run_command

    expose :timeout_ms
    expose :sort_order
    expose :step_type

    expose :stdin_input_file
    expose :expected_output_file

    expose :feedback_message

    expose :status_on_success do |overseer_step|
      overseer_step.status_on_success_id && TaskStatus.find(overseer_step.status_on_success_id).status_key
    end

    expose :status_on_failure do |overseer_step|
      overseer_step.status_on_failure_id && TaskStatus.find(overseer_step.status_on_failure_id).status_key
    end

    expose :halt_on_success
    expose :halt_on_failure
    expose :show_expected_output
    expose :show_stdin
    expose :show_stdout

    expose :enabled
  end
end
