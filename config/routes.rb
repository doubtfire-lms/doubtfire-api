Doubtfire::Application.routes.draw do
	devise_for :users
	
  resources :users, :only => ["index", "show", "edit", "update"]
  resources :home, :only => :index

  root :to => "home#index"
end