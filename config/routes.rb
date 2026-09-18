require 'sidekiq/web'

Doubtfire::Application.routes.draw do
  get 'api/submission/unit/:id/portfolio', to: 'portfolio_downloads#index'
  get 'api/submission/unit/:id/task_definitions/:task_def_id/download_submissions', to: 'task_downloads#index'
  get 'api/submission/unit/:id/task_definitions/:task_def_id/student_pdfs', to: 'task_submission_pdfs#index'
  get 'api/units/:id/all_resources', to: 'lecture_resource_downloads#index'
  post 'api/submission/unit/:id/portfolio/access', to: 'portfolio_download_authorizations#create'
  post 'api/submission/unit/:id/task_definitions/:task_def_id/download_submissions/access',
       to: 'task_submission_files_download_authorizations#create'
  post 'api/submission/unit/:id/task_definitions/:task_def_id/student_pdfs/access',
       to: 'task_submission_pdfs_download_authorizations#create'
  get 'api/units/:unit_id/content/sites/:site_id/files', to: 'unit_content_download_authorizations#serve'
  get 'api/units/:unit_id/content/sites/:site_id/files/*route',
      to: 'unit_content_download_authorizations#serve',
      format: false

  # Caddy-only authorisation subrequests.
  # These authenticate the user, validates it originates from Caddy, then return
  # the path of the file to serve using X-OnTrack-* headers.
  # The file is then served via Caddy
  get 'api/internal/downloads/submission', to: 'submission_download_authorizations#show'
  get 'api/internal/downloads/portfolio', to: 'portfolio_download_authorizations#show'
  get 'api/internal/downloads/task-submission-files', to: 'task_submission_files_download_authorizations#show'
  get 'api/internal/downloads/task-submission-pdfs', to: 'task_submission_pdfs_download_authorizations#show'
  get 'api/internal/downloads/pdf-file', to: 'pdf_file_download_authorizations#show'
  get 'api/internal/downloads/unit-content', to: 'unit_content_download_authorizations#show'

  mount ApiRoot => '/'
  mount GrapeSwaggerRails::Engine => '/api/docs'
  mount Sidekiq::Web => "/sidekiq" # mount Sidekiq::Web in your Rails app

  get "health" => "rails/health#show", as: :rails_health_check
end
