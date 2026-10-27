require 'grape'

module Submission
  class BatchTaskApi < Grape::API
    helpers GenerateHelpers
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers SidekiqHelper

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

    desc 'Upload a batch feedback CSV or zip package for a selected task definition.'
    params do
      requires :file, type: File, desc: 'Batch feedback csv or zip upload'
      requires :unit_id, type: Integer, desc: 'Unit ID to upload marked submissions to.'
      requires :task_definition_id, type: Integer, desc: 'Task definition ID the uploaded CSV relates to.'
    end
    post '/submission/batch_feedback_csv/' do
      unit = Unit.find(params[:unit_id])
      unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, unit, :provide_bulk_feedback
        error!({ error: 'Not authorised to batch upload feedback csv' }, 401)
      end

      error!({ error: "No file uploaded" }, 403) if params[:file].blank?

      import_dir = Rails.root.join(FileHelper.tmp_file_dir, 'batch-feedback')
      FileUtils.mkdir_p(import_dir)

      extension = File.extname(params[:file][:filename].to_s)
      extension = '.upload' if extension.blank?
      file_name = File.join(
        import_dir,
        "batch-feedback-#{unit.id}-#{params[:task_definition_id]}-#{Process.pid}-#{Thread.current.object_id}-#{current_user.id}#{extension}"
      )

      FileUtils.cp(params[:file][:tempfile].path, file_name)

      job_id = ImportBatchFeedbackJob.perform_async(unit.id, current_user.id, params[:task_definition_id], file_name)
      job = setup_job(job_id)
      present job, with: Entities::SidekiqJobEntity
    end

    helpers do
      def authorise_batch_feedback_upload!(unit)
        error!({ error: 'Not authorised to batch upload feedback csv' }, 401) unless authorise?(current_user, unit, :provide_bulk_feedback)
      end

      def find_batch_feedback_upload!
        upload = BatchFeedbackUpload.find(params[:id])
        error!({ error: 'Upload not found' }, 404) if upload.nil? || upload.user_id != current_user.id
        upload
      end
    end

    rescue_from BatchFeedbackUpload::OffsetMismatch do |e|
      error!({ error: e.message, offset: e.offset }, 409)
    end

    rescue_from BatchFeedbackUpload::NotFound do
      error!({ error: 'Upload not found' }, 404)
    end

    rescue_from BatchFeedbackUpload::Error do |e|
      error!({ error: e.message }, 422)
    end

    desc 'Start a chunked batch feedback upload for a selected task definition.'
    params do
      requires :unit_id, type: Integer, desc: 'Unit ID to upload marked submissions to.'
      requires :task_definition_id, type: Integer, desc: 'Task definition ID the upload relates to.'
      requires :filename, type: String, desc: 'Name of the csv or zip being uploaded.'
      requires :size, type: Integer, desc: 'Total size of the upload in bytes.'
    end
    post '/submission/batch_feedback_uploads' do
      unit = Unit.find(params[:unit_id])
      task_definition = unit.task_definitions.find(params[:task_definition_id])
      authorise_batch_feedback_upload!(unit)

      upload = BatchFeedbackUpload.create(
        unit: unit,
        task_definition: task_definition,
        user: current_user,
        filename: params[:filename],
        size: params[:size]
      )
      upload.status
    end

    desc 'Get how much of a chunked batch feedback upload has been received.'
    get '/submission/batch_feedback_uploads/:id' do
      find_batch_feedback_upload!.status
    end

    desc 'Append a chunk to a batch feedback upload.'
    params do
      requires :offset, type: Integer, desc: 'Byte offset this chunk starts at.'
      requires :chunk, type: File, desc: 'The next part of the file.'
      requires :sha256, type: String, regexp: /\A\h{64}\z/, desc: 'Hex SHA-256 of the chunk.'
    end
    patch '/submission/batch_feedback_uploads/:id' do
      upload = find_batch_feedback_upload!
      upload.append(params[:offset], params[:chunk][:tempfile].path, params[:sha256])
      upload.status
    end

    desc 'Finish a batch feedback upload and start importing it.'
    post '/submission/batch_feedback_uploads/:id/complete' do
      upload = find_batch_feedback_upload!
      authorise_batch_feedback_upload!(Unit.find(upload.unit_id))

      job_id = upload.complete! do |path|
        ImportBatchFeedbackJob.perform_async(upload.unit_id, current_user.id, upload.task_definition_id, path)
      end
      job = setup_job(job_id)
      present job, with: Entities::SidekiqJobEntity
    end

    desc 'Cancel a batch feedback upload.'
    delete '/submission/batch_feedback_uploads/:id' do
      find_batch_feedback_upload!.destroy
      body false
    end
  end
end
