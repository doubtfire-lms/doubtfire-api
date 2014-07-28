Doubtfire::Application.routes.draw do
	devise_for :users
  	mount Api::Root => '/'
end
