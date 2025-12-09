require 'grape'

class DiscussionPromptsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc "Get all the discussion prompts for a task definition"
  params do
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
  end
  get '/task_definitions/:task_definition_id/discussion_prompts' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :get_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    result = task_definition.discussion_prompts
                            .order(priority: :desc)

    present result, with: Entities::DiscussionPromptEntity, user: current_user
  end

  desc "Create a new discussion prompt for a task definition"
  params do
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
    requires :content, type: String, desc: 'Discussion prompt content'
    requires :priority, type: Integer, desc: 'The priority of the disucssion prompt'
  end
  post '/task_definitions/:task_definition_id/discussion_prompts' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :create_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    unit = task_definition.unit

    content = params[:content].to_s
    priority = params[:priority].to_i

    discussion_prompt = DiscussionPrompt.create!({
                                                   task_definition: task_definition,
                                                   content: content,
                                                   priority: priority
                                                 })

    present discussion_prompt, with: Entities::DiscussionPromptEntity
  end

  desc "Update a discussion prompt for a task definition"
  params do
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
    requires :content, type: String, desc: 'Discussion prompt content'
    requires :priority, type: Integer, desc: 'The priority of the disucssion prompt'
    requires :id, type: Integer, desc: 'The ID of the discussion prompt'
  end
  put '/task_definitions/:task_definition_id/discussion_prompts/:id' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :create_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    discussion_prompt = task_definition.discussion_prompts.find(params[:id])

    content = params[:content].to_s
    priority = params[:priority].to_i

    discussion_prompt.update({
                               task_definition: task_definition,
                               content: content,
                               priority: priority
                             })
  end

  desc "Delete a discussion prompt for a task definition"
  params do
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
    requires :id, type: Integer, desc: 'The ID of the discussion prompt'
  end
  delete '/task_definitions/:task_definition_id/discussion_prompts/:id' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :create_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    discussion_prompt = task_definition.discussion_prompts.find(params[:id])

    discussion_prompt.destroy!
    present discussion_prompt.destroyed?, with: Grape::Presenters::Presenter
  end

  desc "Get all the discussion prompts for a project"
  params do
    requires :project_id, type: Integer, desc: 'Project to fetch discussion prompts for'
  end
  get 'projects/:project_id/discussion_prompts' do
    project = Project.find(params[:project_id])

    # TODO: should convenor permissions exist on the project ?
    unless authorise? current_user, project, :get_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    tasks_to_discuss = project.tasks.where(task_status: [TaskStatus.discuss, TaskStatus.discuss_check, TaskStatus.demonstrate])
    task_definition_ids = tasks_to_discuss.pluck(:task_definition_id)

    result = DiscussionPrompt
             .joins(:task_definition)
             .where(task_definition_id: task_definition_ids)
             .order('task_definitions.abbreviation ASC, discussion_prompts.priority DESC')

    present result, with: Entities::DiscussionPromptEntity, user: current_user
  end

end
