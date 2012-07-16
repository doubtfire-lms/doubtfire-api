Doubtfire::Application.routes.draw do

	devise_for :users
	
  	resources :users, :only => ["index", "show", "edit", "update"]
  	resources :home, :only => :index
  	resources :projects
  	resources :tasks
  	resources :task_statuses
  	resources :project_statuses
  	resources :teams

  	# If the user is logged in, go to the appropriate page based on their system role (eg. developer dashboard, user listing, etc.)
  	authenticate :user do
  		root :to => "users#index"
  	end

  	# Otherwise, go to the home page
  	root :to => "home#index"
end