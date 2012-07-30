Doubtfire::Application.routes.draw do
  devise_for :users

  resources :users, :path => 'administration/users'   # custom :path separates CRUD interface from Devise
  resources :home, :only => :index
  resources :projects
  resources :project_templates
  resources :task_templates
  resources :project_statuses
  resources :teams
  resources :superuser_administration, :only => :index, :path => 'administration'

  # Student context routes
  resources :projects do
    resources :tasks, :only => :index
  end

  put 'tasks/:task_id/awaiting_signoff/:awaiting_signoff' => 'tasks#awaiting_signoff', :via => :put, :as => 'awaiting_signoff'
  put 'tasks/:task_id/update_task_status/:status' => 'tasks#update_task_status', :via => :put, :as => 'update_task_status'
  get "tasks/index"
  get "tasks/show"

  # Project administrator context routes
  get 'project_templates/:project_template_id/new_task' => 'task_templates#new_project_task', :as => 'new_project_task'
  get 'project_templates/:project_template_id/new_team' => 'teams#new', :as => 'new_project_team'
  post 'project_templates/:project_template_id/update_task/:task_template_id' => 'task_templates#update_project_task', :via => :post, :as => 'update_project_task'
  get 'project_templates/:project_template_id/cancel_update_task/:task_template_id' => 'task_templates#cancel_update_task', :as => 'cancel_update_task'
  post 'project_templates/:project_template_id/update_team/:team_id' => 'teams#update', :via => :post, :as => 'update_project_team'
  get 'project_templates/:project_template_id/cancel_update_team/:team_id' => 'teams#cancel_update', :as => 'cancel_update_project_team'

  # Convenor context routes
  resources :convenor, :only => :index
  get "/convenor/projects/:id"  => "convenor_project#index",  :as => 'convenor_project'

  # Tutor context routes
  get "/tutor/projects/:id" =>                                "tutor_projects#show",  :as => 'tutor_project'
  get "/tutor/projects/:project_id/students/:student_id"  =>  "tutor_project_students#show",  :as => 'tutor_project_student'

  # Go to dashboard home by default
  root :to => "dashboard#index" 

end

