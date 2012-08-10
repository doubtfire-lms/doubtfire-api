Doubtfire::Application.routes.draw do
  devise_for :users, :skip => [:registrations]
  devise_for :users, :skip => [:sessions]
  as :user do
    get 'login' => 'devise/sessions#new', :as => :new_user_session
    post 'login' => 'devise/sessions#create', :as => :user_session
    delete 'logout' => 'devise/sessions#destroy', :as => :destroy_user_session
  end
  
  resources :users # custom :path separates CRUD interface from Devise
  resources :home, :only => :index
  resources :projects
  resources :project_templates
  resources :task_templates
  resources :project_statuses
  resources :teams

  get 'profile' => 'users#edit', :as => 'edit_profile'
  post 'users/update/:id' => 'users#update', :via => :post, :as => 'update_user'
  get 'users/cancel_update_user/:id' => 'users#finish_update', :as => 'cancel_update_user'

  # Student context routes
  resources :projects do
    resources :tasks, :only => [:index, :show]
  end

  put 'tasks/:task_id/awaiting_signoff/:awaiting_signoff' => 'tasks#awaiting_signoff', :via => :put, :as => 'awaiting_signoff'
  put 'tasks/:task_id/update_task_status/:status' => 'tasks#update_task_status', :via => :put, :as => 'update_task_status'

  # Project convenor context routes
  post 'project_templates/:project_template_id/import_users' => 'project_templates#import_users', :via => :post
  post 'project_templates/:project_template_id/import_teams' => 'project_templates#import_teams', :via => :post

  # Project templates
  post 'project_templates/:id/update' => 'project_templates#update', :via => :post, :as => 'update_project_template'
  get 'project_templates/:id/cancel_update' => 'project_templates#finish_update', :as => 'cancel_update_project_template'
  
  # Project tasks
  get 'project_templates/:project_template_id/new_task' => 'task_templates#new', :as => 'new_project_task'
  post 'project_templates/:project_template_id/update_task/:task_template_id' => 'task_templates#update', :via => :post, :as => 'update_project_task'
  get 'project_templates/:project_template_id/cancel_update_task/:task_template_id' => 'task_templates#finish_update', :as => 'cancel_update_project_task'
  
  # Project teams
  get 'project_templates/:project_template_id/new_team' => 'teams#new', :as => 'new_project_team'
  post 'project_templates/:project_template_id/update_team/:team_id' => 'teams#update', :via => :post, :as => 'update_project_team'
  get 'project_templates/:project_template_id/cancel_update_team/:team_id' => 'teams#finish_update', :as => 'cancel_update_project_team'

  # Project users
  get 'project_templates/:project_template_id/add_user' => 'project_templates#add_user', :as => 'add_project_user'
  get 'project_templates/:project_template_id/remove_user/:user_id' => 'project_templates#remove_user', :as => 'remove_project_user'

  # Convenor context routes
  resources :convenor, :only => :index
  get "/convenor/projects/:id"  => "convenor_project#index",  :as => 'convenor_project'

  # Tutor context routes
  get "/tutor/projects/:id" =>                                "tutor_projects#show",  :as => 'tutor_project'
  get "/tutor/projects/:project_id/students/:student_id"  =>  "tutor_project_students#show",  :as => 'tutor_project_student'

  put "team_memberships/:team_membership_id/change_team_allocation/:new_team_id" => "team_memberships#change_team_allocation", :as => 'change_team_allocation'

  # Superuser context routes
  get '/administration' => 'superuser#index', :as => 'superuser_index'

  # Go to dashboard home by default
  root :to => "dashboard#index"
end

