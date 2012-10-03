Doubtfire::Application.routes.draw do
  get "resources/download_task_import_template"

  devise_for :users, :skip => [:registrations, :sessions]

  as :user do
    get 'login'     => 'devise/sessions#new', :as => :new_user_session
    post 'login'    => 'devise/sessions#create', :as => :user_session
    delete 'logout' => 'devise/sessions#destroy', :as => :destroy_user_session
  end
  
  resources :users # custom :path separates CRUD interface from Devise
  resources :home, :only => :index
  resources :projects
  resources :project_templates
  resources :task_templates
  resources :teams

  # Routes for when the user has no projects
  get 'no_projects' => 'convenor_contact_forms#new', :as => 'no_projects'
  post 'convenor_contact' => 'convenor_contact_forms#create', :as => 'convenor_contact'

  resources :convenor_contact_forms, :path_names => { :new => 'welcome' }

  get 'profile' => 'users#edit', :as => 'edit_profile'
  post 'users/update/:id' => 'users#update', :via => :post, :as => 'update_user'
  get 'users/cancel_update_user/:id' => 'users#finish_update', :as => 'cancel_update_user'
  
  # Student context routes
  resources :projects do
    resources :tasks, :only => [:index, :show]
  end

  put 'tasks/:task_id/awaiting_signoff/:awaiting_signoff' => 'tasks#awaiting_signoff', :via => :put,  :as => 'awaiting_signoff'
  put 'tasks/:task_id/engage_with_task/:status'           => 'tasks#engage_with_task', :via => :put,  :as => 'engage_with_task'
  put 'tasks/:task_id/assess_task/:status'                => 'tasks#assess_task',      :via => :put,  :as => 'assess_task'

  # Project convenor context routes
  get 'resources/download_task_import_template' => 'resources#download_task_import_template', :as => 'task_import_template'
  post 'project_templates/:project_template_id/import_users' => 'project_templates#import_users', :via => :post
  post 'project_templates/:project_template_id/import_teams' => 'project_templates#import_teams', :via => :post
  post 'project_templates/:project_template_id/import_tasks' => 'project_templates#import_tasks', :via => :post

  # Project templates
  post 'project_templates/:id/update' => 'project_templates#update', :via => :post, :as => 'update_project_template'
  get 'project_templates/:id/cancel_update' => 'project_templates#finish_update', :as => 'cancel_update_project_template'
  
  # Project tasks
  get 'project_templates/:project_template_id/new_task' => 'task_templates#new', :as => 'new_project_task'
  post 'project_templates/:project_template_id/update_task/:task_template_id' => 'task_templates#update', :via => :post, :as => 'update_project_task'
  get 'project_templates/:project_template_id/cancel_update_task/:task_template_id' => 'task_templates#finish_update', :as => 'cancel_update_project_task'
  get 'project_templates/:project_template_id/destroy_all_tasks' => 'project_templates#destroy_all_tasks', :as => 'destroy_all_project_tasks'
  
  # Project teams
  get 'project_templates/:project_template_id/new_team' => 'teams#new', :as => 'new_project_team'
  post 'project_templates/:project_template_id/update_team/:team_id' => 'teams#update', :via => :post, :as => 'update_project_team'
  get 'project_templates/:project_template_id/cancel_update_team/:team_id' => 'teams#finish_update', :as => 'cancel_update_project_team'

  # Project users
  get 'project_templates/:project_template_id/add_user' => 'project_templates#add_user', :as => 'add_project_user'
  get 'project_templates/:project_template_id/remove_user/:user_id' => 'project_templates#remove_user', :as => 'remove_project_user'

  # Convenor context routes
  resources :convenor, :only => :index
  get "/convenor/projects/:id"  => "convenor_projects#show",  :as => 'convenor_project'
  get "/convenor/project/:id/teams"  => "convenor_project_teams#index",  :as => 'convenor_project_teams'
  get "/convenor/project/:project_template_id/teams/:team_id"  => "convenor_project_teams#show",  :as => 'convenor_project_team'

  # Tutor context routes
  get "/tutor/projects/:id"                                       =>  "tutor_projects#show",                :as => 'tutor_project'
  get "/tutor/projects/:project_id/display_other_team/:team_id"   =>  "tutor_projects#display_other_team",  :as => 'display_other_team'
  get "/tutor/projects/:project_id/students/:student_id"          =>  "tutor_project_students#show",        :as => 'tutor_project_student'

  put "team_memberships/:team_membership_id/change_team_allocation/:new_team_id" => "team_memberships#change_team_allocation", :as => 'change_team_allocation'

  # Superuser context routes
  get '/administration' => 'superuser#index', :as => 'superuser_index'
  post 'users/import' => 'users#import', :via => :post

  # Go to dashboard home by default
  root :to => "dashboard#index"
end

