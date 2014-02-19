Doubtfire::Application.routes.draw do
  devise_for :users

  # namespace :api, defaults: {format: :json} do
  #   devise_scope :user do
  #     post '/auth', to: "sessions#create"
  #   end
  # end

  namespace :api do
    resources :auth, :only => [:create, :destroy]
  end

  ##### Devise #####

  as :user do
    get 'login'     => 'devise/sessions#new', as:  :new_user_session
    post 'login'    => 'devise/sessions#create', as:  :user_session
    delete 'logout' => 'devise/sessions#destroy', as:  :destroy_user_session
  end

  ##### Admin #####

  namespace :admin do
    resources :units
    post 'units/:id' => 'units#update', as: 'unit_update'
    get 'units/:id/cancel_update' => 'units#finish_update', as: 'unit_cancel_update'

    root to: "dashboard#index"
  end

  resources :users # custom :path separates CRUD interface from Devise
  resources :home, only: :index
  resources :projects
  resources :task_definitions
  resources :tutorials

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

  get 'projects/:id/burndown' => 'projects#burndown', as: 'project_burndown'

  post 'units/:id/update'       => 'units#update',       as: 'update_unit'
  get 'units/:id/status_distribution' => 'units#status_distribution', as: 'status_distribution'

  resources :units do
    # Data imports
    post 'import_users' => 'units#import_users'
    post 'import_tutorials' => 'units#import_tutorials'
    post 'import_tasks' => 'units#import_tasks'

    get 'export_tasks' => 'units#export_tasks'

    # Project tasks
    get   'new_task' =>                             'task_definitions#new',                   as: 'new_task'
    post  'update_task/:task_definition_id' =>        'task_definitions#update',                as: 'update_task'
    get   'cancel_update_task/:task_definition_id' => 'task_definitions#finish_update',         as: 'cancel_update_task'
    get   'destroy_all_tasks' =>                    'units#destroy_all_tasks',  as: 'destroy_all_tasks'

    # Project tutorials
    resources :tutorials, only: :new
    post 'tutorials/:tutorial_id' => 'tutorials#update', as: 'tutorial_update'
    get  'cancel_update_tutorial/:tutorial_id' => 'tutorials#finish_update', as: 'cancel_update_tutorial'

    # Project users
    get 'add_user' => 'units#add_user',                 as: 'add_user'
    get 'remove_user/:user_id' => 'units#remove_user',  as: 'remove_user'
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

