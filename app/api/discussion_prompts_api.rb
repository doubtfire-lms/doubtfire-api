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
                            .where(project: nil)
                            .order(weight: :desc)

    present result, with: Entities::DiscussionPromptEntity, user: current_user
  end

  desc "Create a new discussion prompt for a task definition"
  params do
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
    requires :content, type: String, desc: 'Discussion prompt content'
    requires :weight, type: Integer, desc: 'The priority of the disucssion prompt'
    optional :project_id, type: Integer, desc: 'The ID of the project the discussion prompt is for'
  end
  post '/task_definitions/:task_definition_id/discussion_prompts' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :create_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    unit = task_definition.unit

    content = params[:content].to_s
    weight = params[:weight].to_i
    project = unit.projects.find(id: params[:project_id]) if params[:project_id]

    discussion_prompt = DiscussionPrompt.create!({
                                                   task_definition: task_definition,
                                                   content: content,
                                                   weight: weight,
                                                   created_by: current_user
                                                 })

    if project
      discussion_prompt.update!({ project: project })
    end

    present discussion_prompt, with: Entities::DiscussionPromptEntity
  end

  desc "Update a discussion prompt for a task definition"
  params do
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
    requires :content, type: String, desc: 'Discussion prompt content'
    requires :weight, type: Integer, desc: 'The priority of the disucssion prompt'
    requires :id, type: Integer, desc: 'The ID of the discussion prompt'
  end
  put '/task_definitions/:task_definition_id/discussion_prompts/:id' do
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :create_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    discussion_prompt = task_definition.discussion_prompts.find(params[:id])

    content = params[:content].to_s
    weight = params[:weight].to_i

    discussion_prompt.update({
                               task_definition: task_definition,
                               content: content,
                               weight: weight
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

  desc "Get all the discussion prompts for a project's task definition"
  params do
    requires :project_id, type: Integer, desc: 'Project to fetch discussion prompts for'
    requires :task_definition_id, type: Integer, desc: 'Task definition to fetch discussion prompts for'
  end
  get 'projects/:project_id/task_definitions/:task_definition_id/discussion_prompts' do
    project = Project.find(params[:project_id])
    task_definition = TaskDefinition.find(params[:task_definition_id])

    unless authorise? current_user, task_definition, :get_discussion_prompt
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    result = DiscussionPrompt.where(task_definition: task_definition)
                             .where('project_id IS NULL OR project_id = ?', project.id)
                             .order(weight: :desc)

    present result, with: Entities::DiscussionPromptEntity, user: current_user
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

    tasks_to_discuss = project.tasks.where(task_status: [TaskStatus.discuss, TaskStatus.demonstrate])
    task_definition_ids = tasks_to_discuss.pluck(:task_definition_id)

    result = DiscussionPrompt.where(task_definition_id: task_definition_ids)
                             .where('project_id IS NULL OR project_id = ?', project.id)
                             .order(weight: :desc)

    present result, with: Entities::DiscussionPromptEntity, user: current_user
  end

end
