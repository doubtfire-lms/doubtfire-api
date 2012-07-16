Doubtfire::Application.routes.draw do
	devise_for :users
	
  resources :users, :only => ["index", "show", "edit", "update"]
  resources :home, :only => :index
  resources :projects
  resources :tasks
  resources :task_statuses
  resources :project_statuses
  resources :teams

  root :to => "home#index"
end