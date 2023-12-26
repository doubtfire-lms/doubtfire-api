require 'sidekiq/web'

Doubtfire::Application.routes.draw do
  devise_for :users
  get 'api/submission/unit/:id/portfolio', to: 'portfolio_downloads#index'
  get 'api/submission/unit/:id/task_definitions/:task_def_id/download_submissions', to: 'task_downloads#index'
  get 'api/submission/unit/:id/task_definitions/:task_def_id/student_pdfs', to: 'task_submission_pdfs#index'
  get 'api/units/:id/all_resources', to: 'lecture_resource_downloads#index'

  mount ApiRoot => '/'
  mount GrapeSwaggerRails::Engine => '/api/docs'
  mount Sidekiq::Web => "/sidekiq" # mount Sidekiq::Web in your Rails app
end
