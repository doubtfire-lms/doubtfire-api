Doubtfire::Application.routes.draw do

  root :to => "home#index"

  devise_for :users
  resources :users, :only => ["index", "show", "edit", "update"]
end
