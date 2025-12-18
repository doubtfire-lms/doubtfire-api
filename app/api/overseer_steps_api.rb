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
      optional :timeout_ms, type: Integer
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
    # unless authorise? current_user, User, :admin_overseer
    #   error!({ error: 'Not authorised to create overseer images' }, 403)
    # end
    # TODO: ensure correct permissions

    task_definition = TaskDefinition.find(params[:task_def_id])

    unless Doubtfire::Application.config.overseer_enabled
      error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
    end

    # status_on_success = TaskStatus.status_for_name(params[:status_on_success])
    # status_on_failure = TaskStatus.status_for_name(params[:status_on_failure])

    status_on_success_id = params[:status_on_success].present? && params[:status_on_success] != 'no_change' ? TaskStatus.status_for_name(params[:status_on_success])&.id : nil
    status_on_failure_id = params[:status_on_failure].present? && params[:status_on_failure] != 'no_change' ? TaskStatus.status_for_name(params[:status_on_failure])&.id : nil

    # status_on_success_id = TaskStatus.status_for_name(params[:status_on_success])&.id
    # status_on_failure_id = TaskStatus.status_for_name(params[:status_on_failure])&.id

    overseer_step_params = ActionController::Parameters.new(params)
                                                       .require(:overseer_step)
                                                       .permit(
                                                         :name,
                                                         :description,
                                                         :display_name,
                                                         :display_description,
                                                         :run_command,
                                                         :timeout_ms,
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
      optional :timeout_ms, type: Integer
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
    # unless authorise? current_user, User, :admin_overseer
    #   error!({ error: 'Not authorised to create overseer images' }, 403)
    # end
    # TODO: ensure correct permissions

    unless Doubtfire::Application.config.overseer_enabled
      error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
    end

    overseer_step = OverseerStep.find(params[:id])

    status_on_success_id = params[:status_on_success].present? ? TaskStatus.status_for_name(params[:status_on_success])&.id : nil
    status_on_failure_id = params[:status_on_failure].present? ? TaskStatus.status_for_name(params[:status_on_failure])&.id : nil

    overseer_step_params = ActionController::Parameters.new(params)
                                                       .require(:overseer_step)
                                                       .permit(
                                                         :name,
                                                         :description,
                                                         :display_name,
                                                         :display_description,
                                                         :run_command,
                                                         :timeout_ms,
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
    #  .merge(task_definition_id: task_definition.id)

    overseer_step.update!(overseer_step_params)

    present overseer_step, with: Entities::OverseerStepEntity
  end

  desc 'Delete an overseer step'
  delete '/overseer_steps/:id' do
    # unless authorise? current_user, User, :admin_overseer
    #   error!({ error: 'Not authorised to delete an overseer image' }, 403)
    # end

    # TODO: permissions

    overseer_step = OverseerStep.find(params[:id])
    overseer_step.destroy!

    error!({ error: overseer_step.errors.full_messages.last }, 403) unless overseer_step.destroyed?

    present overseer_step.destroyed?, with: Grape::Presenters::Presenter
  end

  #
  # desc 'Update an overseer image'
  # params do
  #   requires :overseer_image, type: Hash do
  #     optional :name, type: String,  desc: 'The name of the overseer image'
  #     optional :tag,  type: String,  desc: 'The tag used to receive from container repo'
  #   end
  # end
  # put '/admin/overseer_images/:id' do
  #   unless authorise? current_user, User, :admin_overseer
  #     error!({ error: 'Not authorised to update an overseer image' }, 403)
  #   end
  #   unless Doubtfire::Application.config.overseer_enabled
  #     error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
  #   end

  #   overseer_image = OverseerImage.find(params[:id])

  #   overseer_image_params = ActionController::Parameters.new(params)
  #                                                       .require(:overseer_image)
  #                                                       .permit(:name,
  #                                                               :tag)

  #   # Clear image status and text when updating
  #   overseer_image_params[:pulled_image_status] = nil
  #   overseer_image_params[:pulled_image_text] = nil
  #   overseer_image_params[:last_pulled_date] = nil

  #   overseer_image.update!(overseer_image_params)
  #   present overseer_image, with: Entities::OverseerImageEntity
  # end

  # desc 'Get all overseer images'
  # get '/admin/overseer_images' do
  #   unless authorise? current_user, User, :use_overseer
  #     error!({ error: 'Not authorised to get overseer images' }, 403)
  #   end

  #   if Doubtfire::Application.config.overseer_enabled
  #     present OverseerImage.all, with: Entities::OverseerImageEntity
  #   else
  #     present [], with: Grape::Presenters::Presenter
  #   end
  # end

  # desc 'Get all overseer images'
  # get '/admin/overseer_images/:id' do
  #   unless authorise? current_user, User, :use_overseer
  #     error!({ error: 'Not authorised to get overseer images' }, 403)
  #   end

  #   if Doubtfire::Application.config.overseer_enabled
  #     present OverseerImage.find(params[:id]), with: Entities::OverseerImageEntity
  #   else
  #     present [], with: Grape::Presenters::Presenter
  #   end
  # end

  # desc 'Get overseer image by id and pull image'
  # put '/admin/overseer_images/:id/pull_image' do
  #   unless authorise? current_user, User, :admin_overseer
  #     error!({ error: 'Not authorised to pull an overseer image' }, 403)
  #   end
  #   unless Doubtfire::Application.config.overseer_enabled
  #     error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
  #   end

  #   overseer_image = OverseerImage.find(params[:id])

  #   job_id = PullDockerImageJob.perform_async(overseer_image.id)
  #   job = setup_job(job_id)

  #   present job, with: Entities::SidekiqJobEntity
  # end
end
