Doubtfire::Application.routes.draw do
  get "tasks/index"

  get "tasks/show"

  devise_for :users

  resources :users
  resources :home, :only => :index
  resources :projects
  resources :project_templates
  resources :task_statuses
  resources :project_statuses
  resources :teams

  resources :projects do
    resources :tasks, :only => :index
  end

  # Otherwise, go to the home page
  root :to => "dashboard#index"
end