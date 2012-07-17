Doubtfire::Application.routes.draw do

  get "dashboard/index"

	devise_for :users

	resources :users, :only => ["index", "show", "edit", "update"]
	resources :home, :only => :index
	resources :projects
	resources :tasks
	resources :task_statuses
	resources :project_statuses
	resources :teams

	authenticate :user do
		root :to => "dashboard#index"
	end

	# Otherwise, go to the home page
	root :to => "home#index"
end