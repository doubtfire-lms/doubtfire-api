require 'sidekiq/web'

Doubtfire::Application.routes.draw do
  get 'api/submission/unit/:id/portfolio', to: 'portfolio_downloads#index'
  get 'api/submission/unit/:id/task_definitions/:task_def_id/download_submissions', to: 'task_downloads#index'
  get 'api/submission/unit/:id/task_definitions/:task_def_id/student_pdfs', to: 'task_submission_pdfs#index'
  get 'api/units/:id/all_resources', to: 'lecture_resource_downloads#index'
  get 'api/internal/downloads/unit-content', to: 'unit_content_download_authorizations#show'
  get 'api/units/:unit_id/content/sites/:site_id/files', to: 'unit_content_download_authorizations#serve'
  get 'api/units/:unit_id/content/sites/:site_id/files/*route',
      to: 'unit_content_download_authorizations#serve',
      format: false

  mount ApiRoot => '/'
  mount GrapeSwaggerRails::Engine => '/api/docs'
  mount Sidekiq::Web => "/sidekiq" # mount Sidekiq::Web in your Rails app

  get "health" => "rails/health#show", as: :rails_health_check
end
