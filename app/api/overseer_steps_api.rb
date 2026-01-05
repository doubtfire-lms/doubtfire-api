require 'grape'

class OverseerStepsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers SidekiqHelper

  before do
    authenticated?
  end

  desc 'Add an overseer step'
  params do
    requires :overseer_step, type: Hash do
      requires :name, type: String
      optional :description, type: String
      optional :display_name, type: String
      optional :display_description, type: String
      optional :run_command, type: String
      optional :timeout, type: Integer
      # TODO: rename to execution_order || exec_order?
      optional :sort_order, type: Integer
      optional :partial_output_diff, type: Boolean
      requires :step_type, type: String
      optional :stdin_input_file, type: String
      optional :expected_output_file, type: String
      optional :feedback_message, type: String
      optional :status_on_success, type: String
      optional :status_on_failure, type: String
      optional :halt_on_success, type: Boolean
      optional :halt_on_failure, type: Boolean
      optional :show_expected_output, type: Boolean
      optional :show_stdin, type: Boolean
      optional :show_stdout, type: Boolean
      optional :enabled, type: Boolean
    end
    requires :task_def_id, type: Integer
  end
  post '/units/:unit_id/task_definitions/:task_def_id/overseer_steps' do
    unless Doubtfire::Application.config.overseer_enabled
      error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
    end

    task_definition = TaskDefinition.find(params[:task_def_id])

    unless authorise? current_user, overseer_step.task_definition, :manage_overseer_steps
      error!({ error: 'Not authorised to manage overseer for this task definition' }, 403)
    end

    status_on_success_param = params[:overseer_step][:status_on_success]
    status_on_failure_param = params[:overseer_step][:status_on_failure]

    status_on_success_id = status_on_success_param.present? && status_on_success_param != 'no_change' ? TaskStatus.status_for_name(status_on_success_param)&.id : nil
    status_on_failure_id = status_on_failure_param.present? && status_on_failure_param != 'no_change' ? TaskStatus.status_for_name(status_on_failure_param)&.id : nil

    overseer_step_params = ActionController::Parameters.new(params)
                                                       .require(:overseer_step)
                                                       .permit(
                                                         :name,
                                                         :description,
                                                         :display_name,
                                                         :display_description,
                                                         :run_command,
                                                         :timeout,
                                                         :sort_order,
                                                         :step_type,
                                                         :partial_output_diff,
                                                         :stdin_input_file,
                                                         :expected_output_file,
                                                         :feedback_message,
                                                         :status_on_success_id,
                                                         :status_on_failure_id,
                                                         :halt_on_success,
                                                         :halt_on_failure,
                                                         :show_expected_output,
                                                         :show_stdin,
                                                         :show_stdout,
                                                         :enabled
                                                       )
                                                       .merge(task_definition_id: task_definition.id,
                                                              status_on_success_id: status_on_success_id,
                                                              status_on_failure_id: status_on_failure_id)

    result = OverseerStep.create!(overseer_step_params)

    if result.nil?
      error!({ error: 'No overseer step added' }, 403)
    else
      present result, with: Entities::OverseerStepEntity
    end
  end

  desc 'Update an overseer step'
  params do
    requires :overseer_step, type: Hash do
      optional :name, type: String
      optional :description, type: String
      optional :display_name, type: String
      optional :display_description, type: String
      optional :run_command, type: String
      optional :timeout, type: Integer
      optional :sort_order, type: Integer
      optional :step_type, type: String
      optional :partial_output_diff, type: Boolean
      optional :stdin_input_file, type: String
      optional :expected_output_file, type: String
      optional :feedback_message, type: String
      optional :status_on_success, type: String
      optional :status_on_failure, type: String
      optional :halt_on_success, type: Boolean
      optional :halt_on_failure, type: Boolean
      optional :show_expected_output, type: Boolean
      optional :show_stdin, type: Boolean
      optional :show_stdout, type: Boolean
      optional :enabled, type: Boolean
    end
    requires :task_def_id, type: Integer
  end
  put '/units/:unit_id/task_definitions/:task_def_id/overseer_steps/:id' do
    unless Doubtfire::Application.config.overseer_enabled
      error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
    end

    overseer_step = OverseerStep.find(params[:id])

    unless authorise? current_user, overseer_step.task_definition, :manage_overseer_steps
      error!({ error: 'Not authorised to manage overseer for this task definition' }, 403)
    end

    status_on_success_param = params[:overseer_step][:status_on_success]
    status_on_failure_param = params[:overseer_step][:status_on_failure]

    status_on_success_id = status_on_success_param.present? && status_on_success_param != 'no_change' ? TaskStatus.status_for_name(status_on_success_param)&.id : nil
    status_on_failure_id = status_on_failure_param.present? && status_on_failure_param != 'no_change' ? TaskStatus.status_for_name(status_on_failure_param)&.id : nil

    overseer_step_params = ActionController::Parameters.new(params)
                                                       .require(:overseer_step)
                                                       .permit(
                                                         :name,
                                                         :description,
                                                         :display_name,
                                                         :display_description,
                                                         :run_command,
                                                         :timeout,
                                                         :sort_order,
                                                         :step_type,
                                                         :partial_output_diff,
                                                         :stdin_input_file,
                                                         :expected_output_file,
                                                         :feedback_message,
                                                         :status_on_success_id,
                                                         :status_on_failure_id,
                                                         :halt_on_success,
                                                         :halt_on_failure,
                                                         :show_expected_output,
                                                         :show_stdin,
                                                         :show_stdout,
                                                         :enabled
                                                       )
                                                       .merge(
                                                         status_on_success_id: status_on_success_id,
                                                         status_on_failure_id: status_on_failure_id
                                                       )

    overseer_step.update!(overseer_step_params)

    present overseer_step, with: Entities::OverseerStepEntity
  end

  desc 'Delete an overseer step'
  delete '/overseer_steps/:id' do
    overseer_step = OverseerStep.find(params[:id])

    unless authorise? current_user, overseer_step.task_definition, :manage_overseer_steps
      error!({ error: 'Not authorised to manage overseer for this task definition' }, 403)
    end

    overseer_step.destroy!

    error!({ error: overseer_step.errors.full_messages.last }, 403) unless overseer_step.destroyed?

    present overseer_step.destroyed?, with: Grape::Presenters::Presenter
  end

  desc 'Get test results for an overseer assessment'
  get '/projects/:project_id/task_definitions/:task_def_id/overseer_assessments_results/:id' do
    project = Project.find(params[:project_id])

    unless authorise? current_user, project, :get_submission
      error!({ error: 'Not authorised to view this project' }, 403)
    end

    unit = project.unit

    overseer_assessment = OverseerAssessment.find(params[:id])
    present overseer_assessment.overseer_step_results, with: Entities::OverseerStepResultEntity, my_role: unit.role_for(current_user)
  end
end
