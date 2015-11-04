Doubtfire::Application.routes.draw do
	devise_for :users
  	mount Api::Root => '/'

  	get 'api/submission/unit/:id/portfolio', to: 'portfolio_downloads#index'
end
