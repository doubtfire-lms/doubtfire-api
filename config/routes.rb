Doubtfire::Application.routes.draw do
  get "tasks/index"
  get "tasks/show"

  devise_for :users

  resources :users, :path => 'administration/users'   # custom :path separates CRUD interface from Devise
  resources :home, :only => :index
  resources :projects
  resources :project_templates
  resources :task_statuses
  resources :project_statuses
  resources :teams
  resources :superuser_administration, :only => :index, :path => 'administration'
  resources :convenor, :only => :index
  match "/convenor/projects/:id" => "convenor_project#index"

  resources :projects do
    resources :tasks, :only => :index
    put 'tasks/:task_id/complete' => 'tasks#complete', :via => :put, :as => 'complete'
  end

  root :to => "dashboard#index" 

end
