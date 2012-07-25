Doubtfire::Application.routes.draw do
  get "tasks/index"
  get "tasks/show"

  devise_for :users

  resources :users, :path => 'administration/users'   # custom :path separates CRUD interface from Devise
  resources :home, :only => :index
  resources :projects
  resources :project_templates
  resources :task_templates
  resources :project_statuses
  resources :teams
  resources :superuser_administration, :only => :index, :path => 'administration'
  resources :convenor, :only => :index
  get "/convenor/projects/:id" => "convenor_project#index", :as => 'convenor_project'

  resources :projects do
    resources :tasks, :only => :index
  end

  get 'project_templates/:project_template_id/new_task' => 'task_templates#new', :as => 'new_project_task'

  put 'tasks/:task_id/awaiting_signoff/:awaiting_signoff' => 'tasks#awaiting_signoff', :via => :put, :as => 'awaiting_signoff'
  put 'tasks/:task_id/update_task_status/:status' => 'tasks#update_task_status', :via => :put, :as => 'update_task_status'

  root :to => "dashboard#index" 

end
