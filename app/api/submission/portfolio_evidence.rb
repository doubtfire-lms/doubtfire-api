require 'grape'
require 'project_serializer'
require 'zip'

# getting file MIME types
require 'filemagic'
# image to pdf
require 'RMagick'
# code to html
require 'coderay'
# html to pdf
require 'pdfkit'

module Api
  module Submission
    class PortfolioEvidence < Grape::API
      helpers GenerateHelpers
      helpers AuthHelpers
      helpers AuthorisationHelpers
    
      before do
        authenticated?
      end
      
      desc "Upload and generate doubtfire-task-specific submission document"
      params do
        requires :file0, type: Rack::Multipart::UploadedFile, :desc => "file 0."
        optional :file1, type: Rack::Multipart::UploadedFile, :desc => "file 1."
      end
      post '/submission/task/:id' do
        task = Task.find(params[:id])

        if task.discuss? || task.complete? || task.fix_and_include?
          msg = { :complete => "is already complete", :discuss => "is ready to discuss with your tutor", :fix_and_include => "has been marked as fix and include. You may no longer submit this task" }
          error!({"error" => "#{task.task_definition.name} #{msg[task.status]}."}, 401)
        end
        
        upload_reqs = task.upload_requirements
        student = task.project.student
        unit = task.project.unit
        
        # The filepath where to store this upload...
        dst = student_work_dir(unit, student, task)

        # Remember to delete the file as we don't want to save it with this kind of inspecific request
        file = combine_to_pdf(scoop_files(params, upload_reqs))
        FileUtils.cp file.path, dst
        
        # This task is now ready to submit
        task.trigger_transition 'ready_to_mark', current_user
        
        # Remove the tempfile and set portfolio_evidence to the stored file directory
        file.unlink
        task = Task.update(task.id, :portfolio_evidence => dst)

        TaskUpdateSerializer.new(task)
      end #post
      
      desc "Retrieve submission document included for the task id"
      get '/submission/task/:id' do
        task = Task.find(params[:id])        
        evidence_loc = task.portfolio_evidence
        student = task.project.student
        unit = task.project.unit
        
        if evidence_loc.nil?
          error!({"error" => "No submission under task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        if not authorise? current_user, task, :get_submission
          error!({"error" => "Not authorised to get task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        
        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{task.task_definition.abbreviation}.pdf"
        env['api.format'] = :binary

        File.read(evidence_loc)
      end
      
      desc "Retrieve all submission documents ready to mark for the provided user's tutorials for the given unit id"
      params do
        requires :unit_id, type: Integer, :desc => "Unit ID to retrieve submissions for."
        optional :user_id, type: Integer, :desc => "User ID to retrieve submissions for (optional; will use current_user otherwise)."
      end
      get '/submission/assess/' do
        user = params[:user_id].nil? ? current_user : User.find(params[:user_id])
        unit = Unit.find(params[:unit_id])
        
        if not authorise? user, unit, :get_ready_to_mark_submissions
          error!({"error" => "Not authorised to batch download ready to mark submissions"}, 401)        
        end
        
        # Array of tasks that need marking for the given unit id
        tasks_ready_to_mark = UnitRole.tasks_ready_to_mark(current_user).reject{| task | task.project.unit.id != unit.id }
        download_id = "#{Time.new.strftime("%Y-%m-%d")}-#{unit.code}-#{current_user.username}"
        output_zip = Tempfile.new(["batch_ready_to_mark_#{current_user.username}", ".zip"])
        
        # Create a new zip
        Zip::File.open(output_zip.path, Zip::File::CREATE) do | zip |
          csv_str = ""
          tasks_ready_to_mark.each do | task |
            # Add to the template entry string
            csv_str << "#{task.project.student.username},ready_to_mark|discuss|fix_and_resubmit|fix_and_include|redo\n"
            src_path = task.portfolio_evidence
            # make dst path of "<student id>/<task abbrev>.pdf"
            dst_path = "#{task.project.student.username}/#{task.task_definition.abbreviation}.pdf"
            # now copy it over
            zip.add(dst_path, src_path)
          end
          # Add marking file
          zip.get_output_stream("marks.csv") { |f| f.puts csv_str }
        end
        
        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{download_id}.zip"
        env['api.format'] = :binary

        out = File.read(output_zip.path)
        output_zip.unlink
        out
      end #get
    end
  end
end