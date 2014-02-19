Doubtfire::Application.routes.draw do
  mount Api::Root => '/'
  
  namespace :api do
    resources :auth, :only => [:create, :destroy]
  end

  devise_for :users, path: '', path_names: { sign_in: 'login', sign_out: 'logout', sign_up: 'register'}
end
