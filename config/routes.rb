Doubtfire::Application.routes.draw do
  devise_for :users, :skip => [:registrations, :sessions]

  as :user do
    get 'login'     => 'devise/sessions#new', :as => :new_user_session
    post 'login'    => 'devise/sessions#create', :as => :user_session
    delete 'logout' => 'devise/sessions#destroy', :as => :destroy_user_session
  end
  
  resources :users # custom :path separates CRUD interface from Devise
  resources :home, :only => :index
  resources :projects
  resources :task_templates
  resources :teams

  # Routes for when the user has no projects
  get 'no_projects' => 'convenor_contact_forms#new', :as => 'no_projects'

  get 'profile' => 'users#edit', :as => 'edit_profile'
  post 'users/update/:id' => 'users#update', :via => :post, :as => 'update_user'
  get 'users/cancel_update_user/:id' => 'users#finish_update', :as => 'cancel_update_user'
  post 'users/import' => 'users#import', :via => :post

  # Student context routes
  resources :projects do
    resources :tasks, :only => [:index, :show]
  end

  # Tasks
  put 'tasks/:id/submit/:submission_status' => 'tasks#submit',            as: 'submit_task'
  put 'tasks/:id/engage_with_task/:status'  => 'tasks#engage_with_task',  as: 'engage_with_task'
  put 'tasks/:id/assess_task/:status'       => 'tasks#assess_task',       as: 'assess_task'

  post 'project_templates/:id/update'       => 'project_templates#update',       as: 'update_project_template'

  resources :project_templates do
    # Data imports
    post 'import_users' => 'project_templates#import_users'
    post 'import_teams' => 'project_templates#import_teams'
    post 'import_tasks' => 'project_templates#import_tasks'

    # Intermediate state management (via AJAX)
    get 'cancel_update' => 'project_templates#finish_update', as: 'cancel_update'

    # Project tasks
    get   'new_task' =>                             'task_templates#new',                   as: 'new_task'
    post  'update_task/:task_template_id' =>        'task_templates#update',                as: 'update_task'
    get   'cancel_update_task/:task_template_id' => 'task_templates#finish_update',         as: 'cancel_update_task'
    get   'destroy_all_tasks' =>                    'project_templates#destroy_all_tasks',  as: 'destroy_all_tasks'

    # Project teams
    get   'new_team' => 'teams#new',                              as: 'new_team'
    post  'update_team/:team_id' => 'teams#update',               as: 'update_team'
    get   'cancel_update_team/:team_id' => 'teams#finish_update', as: 'cancel_update_team'

    # Project users
    get 'add_user' => 'project_templates#add_user',                 as: 'add_user'
    get 'remove_user/:user_id' => 'project_templates#remove_user',  as: 'remove_user'
  end

  # Convenor context routes
  resources :convenor, :only => :index

  scope '/convenor' do
    get 'projects'                                      => "convenor_projects#index",       as: 'convenor_projects'
    get 'projects/:id'                                  => "convenor_projects#show",        as: 'convenor_project'
    get 'projects/:id/teams'                            => "convenor_project_teams#index",  as: 'convenor_project_teams'
    get 'projects/:project_template_id/teams/:team_id'  => "convenor_project_teams#show",   as: 'convenor_project_team'
  end

  resources :convenor_contact_forms, :path_names => { :new => 'welcome' }
  post 'convenor_contact' => 'convenor_contact_forms#create', :as => 'convenor_contact'

  # Tutor context routes
  scope '/tutor' do
    get 'projects/:id'                                        => 'tutor_projects#show',               as: 'tutor_project'
    get 'projects/:project_id/display_other_team/:team_id'    => 'tutor_projects#display_other_team', as: 'display_other_team'
    get 'projects/:project_id/students/:student_id'           => 'tutor_project_students#show',       as: 'tutor_project_student'
  end

  put "team_memberships/:team_membership_id/change_team_allocation/:new_team_id" => "team_memberships#change_team_allocation", :as => 'change_team_allocation'

  # Superuser context routes
  get '/administration' => 'superuser#index', :as => 'superuser_index'

  # Static resources
  scope '/resources' do
    get 'download_task_import_template' => 'resources#download_task_import_template', as: 'task_import_template'
  end

  # Go to dashboard home by default
  root :to => "dashboard#index"
end

