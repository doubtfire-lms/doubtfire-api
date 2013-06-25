Doubtfire::Application.routes.draw do
  devise_for :users, skip:  [:registrations, :sessions]

  as :user do
    get 'login'     => 'devise/sessions#new', as:  :new_user_session
    post 'login'    => 'devise/sessions#create', as:  :user_session
    delete 'logout' => 'devise/sessions#destroy', as:  :destroy_user_session
  end
  
  resources :users # custom :path separates CRUD interface from Devise
  resources :home, only:  :index
  resources :projects
  resources :task_definitions
  resources :tutorials

  # Routes for when the user has no projects
  get 'no_projects' => 'convenor_contact_forms#new', as:  'no_projects'

  get 'profile' => 'users#edit', as:  'edit_profile'
  post 'users/update/:id' => 'users#update', via:  :post, as:  'update_user'
  get 'users/cancel_update_user/:id' => 'users#finish_update', as:  'cancel_update_user'
  post 'users/import' => 'users#import', via:  :post

  # Student context routes
  resources :projects do
    resources :tasks, only:  [:index, :show]
  end

  # Tasks
  put 'tasks/:id/submit/:submission_status' => 'tasks#submit',            as: 'submit_task'
  put 'tasks/:id/engage_with_task/:status'  => 'tasks#engage_with_task',  as: 'engage_with_task'
  put 'tasks/:id/assess_task/:status'       => 'tasks#assess_task',       as: 'assess_task'

  post 'units/:id/update'       => 'units#update',       as: 'update_unit'
  get 'units/:id/status_distribution' => 'units#status_distribution', as: 'status_distribution'

  resources :units do
    # Data imports
    post 'import_users' => 'units#import_users'
    post 'import_tutorials' => 'units#import_tutorials'
    post 'import_tasks' => 'units#import_tasks'

    get 'export_tasks' => 'units#export_tasks'

    # Intermediate state management (via AJAX)
    get 'cancel_update' => 'units#finish_update', as: 'cancel_update'

    # Project tasks
    get   'new_task' =>                             'task_definitions#new',                   as: 'new_task'
    post  'update_task/:task_definition_id' =>        'task_definitions#update',                as: 'update_task'
    get   'cancel_update_task/:task_definition_id' => 'task_definitions#finish_update',         as: 'cancel_update_task'
    get   'destroy_all_tasks' =>                    'units#destroy_all_tasks',  as: 'destroy_all_tasks'

    # Project tutorials
    get   'new_tutorial' => 'tutorials#new',                              as: 'new_tutorial'
    post  'update_tutorial/:tutorial_id' => 'tutorials#update',               as: 'update_tutorial'
    get   'cancel_update_tutorial/:tutorial_id' => 'tutorials#finish_update', as: 'cancel_update_tutorial'

    # Project users
    get 'add_user' => 'units#add_user',                 as: 'add_user'
    get 'remove_user/:user_id' => 'units#remove_user',  as: 'remove_user'
  end

  # Convenor context routes
  resources :convenor, only:  :index

  scope '/convenor' do
    get 'unit'                                  => "convenor_units#index",            as: 'convenor_units'
    get 'unit/:id'                              => "convenor_units#show",             as: 'convenor_unit'
    get 'unit/:id/export_tasks'                 => 'convenor_units#export_tasks',     as: 'convenor_unit_export_tasks'
    get 'unit/:id/tutorials'                    => "convenor_unit_tutorials#index",   as: 'convenor_unit_tutorials'
    get 'unit/:unit_id/tutorials/:tutorial_id'  => "convenor_unit_tutorials#show",    as: 'convenor_unit_tutorial'
  end

  resources :convenor_contact_forms, path_names:  { new:  'welcome' }
  post 'convenor_contact' => 'convenor_contact_forms#create', as:  'convenor_contact'

  # Tutor context routes
  scope '/tutor' do
    get 'projects/:id'                                        => 'tutor_projects#show',               as: 'tutor_project'
    get 'projects/:project_id/display_other_tutorial/:tutorial_id'    => 'tutor_projects#display_other_tutorial', as: 'display_other_tutorial'
    get 'projects/:project_id/students/:student_id'           => 'tutor_project_students#show',       as: 'tutor_project_student'
  end

  put "unit_roles/:unit_role_id/change_tutorial_allocation/:new_tutorial_id" => "unit_roles#change_tutorial_allocation", as:  'change_tutorial_allocation'

  # Admin context routes
  get '/admin' => 'admin#index', as:  'admin_index'

  # Static resources
  scope '/resources' do
    get 'download_task_import_template' => 'resources#download_task_import_template', as: 'task_import_template'
  end

  # Go to dashboard home by default
  root to:  "dashboard#index"
end

