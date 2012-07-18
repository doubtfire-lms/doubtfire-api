Doubtfire::Application.routes.draw do

    devise_for :users

    resources :users, :path => 'administration/users'   # custom :path separates CRUD interface from Devise
    resources :home, :only => :index
    resources :project_templates
    resources :tasks
    resources :task_statuses
    resources :project_statuses
    resources :teams
    resources :administration, :only => :index

    root :to => "dashboard#index" 
end