module Entities
  class OverseerStepResultEntity < Grape::Entity

    def staff?(my_role)
      Role.teaching_staff_ids.include?(my_role.id) unless my_role.nil?
    end

    expose :id
    expose :overseer_step_id
    expose :exit_status
    expose :pass
    expose :feedback_message

    expose :stdout, if: lambda { |result, options|
      staff?(options[:my_role]) || result.overseer_step&.show_stdout
    }

    expose :stdin, if: lambda { |result, options|
      staff?(options[:my_role]) || result.overseer_step&.show_stdin
    }

    expose :expected_output, if: lambda { |result, options|
      staff?(options[:my_role]) || result.overseer_step&.show_expected_output
    }

    expose :stdout_sha256
    expose :stdin_sha256
    expose :expected_output_sha256
  end
end
