require 'grape'

module Submission
  class BatchTaskApi < Grape::API
    helpers GenerateHelpers
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    # desc "Retrieve all submission documents ready to mark for the provided user's tutorials for the given unit id"
    # params do
    #   requires :unit_id, type: Integer, desc: 'Unit ID to retrieve submissions for.'
    #   optional :user_id, type: Integer, desc: 'User ID to retrieve submissions for (optional; will use current_user otherwise).'
    # end
    # get '/submission/assess/' do
    #   user = params[:user_id].nil? ? current_user : User.find(params[:user_id])
    #   unit = Unit.find(params[:unit_id])

    #   unless authorise? user, unit, :provide_feedback
    #     error!({ error: 'Not authorised to batch download ready to mark submissions' }, 401)
    #   end

    #   unless authorise? current_user, unit, :provide_feedback
    #     error!({ error: 'Not authorised to batch download ready to mark submissions' }, 401)
    #   end

    #   # Array of tasks that need marking for the given unit id
    #   tasks_to_download = UnitRole.tasks_to_review(user)

    #   output_zip = unit.generate_batch_task_zip(current_user, tasks_to_download)

    #   error!({ error: 'No files to download' }, 401) if output_zip.nil?

    #   # Set download headers...
    #   content_type 'application/octet-stream'
    #   download_id = "#{Time.zone.now.strftime('%Y-%m-%d')}-#{unit.code}-#{current_user.username}"
    #   header['Content-Disposition'] = "attachment; filename=#{download_id}.zip"
    #   env['api.format'] = :binary

    #   stream_file output_zip
    # ensure
    #   File.unlink(output_zip) unless output_zip.blank?
    # end # get

    # desc 'Upload submission documents for the given unit and user id'
    # params do
    #   requires :file, type: File, desc: 'batch file upload'
    #   requires :unit_id, type: Integer, desc: 'Unit ID to upload marked submissions to.'
    #   optional :user_id, type: Integer, desc: 'User ID to upload marked submissions to (optional; will use current_user otherwise).'
    # end
    # post '/submission/assess/' do
    #   user = params[:user_id].nil? ? current_user : User.find(params[:user_id])
    #   unit = Unit.find(params[:unit_id])

    #   unless authorise? user, unit, :provide_feedback
    #     error!({ error: 'Not authorised to batch upload marks' }, 401)
    #   end

    #   present unit.upload_batch_task_zip_or_csv(current_user, params[:file]), with: Grape::Presenters::Presenter
    # end # post
  end
end
