Doubtfire::Application.routes.draw do
  devise_for :users

  resources :users
  resources :home, :only => :index
  resources :project_templates
  resources :tasks
  resources :task_statuses
  resources :project_statuses
  resources :teams

  # Otherwise, go to the home page
  root :to => "dashboard#index"
end