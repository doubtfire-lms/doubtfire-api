require 'grape'
require 'project_serializer'

module Api
  module Submission
    class PortfolioApi < Grape::API
      helpers GenerateHelpers
      helpers AuthHelpers
      helpers AuthorisationHelpers
    
      before do
        authenticated?
      end
      
      desc "Upload documents for inclusion in a project's portfolio"
      params do
        requires :name,  type: String,                        :desc => "Name of the part being uploaded"
        requires :kind,  type: String,                        :desc => "The kind of file being uploaded: document, code, or image"
        requires :file0, type: Rack::Multipart::UploadedFile, :desc => "file 0."
      end
      post '/submission/project/:id/portfolio' do
        project = Project.find(params[:id])

        if not authorise? current_user, project, :make_submission
          error!({"error" => "Not authorised to submit portfolio for project '#{params[:id]}'"}, 401)
        end

        file = params[:file0]
        name = params[:name]
        kind = params[:kind]

        # Check that the file is OK to accept
        if not FileHelper.accept_file(file, name, kind)
          error!({"error" => "'#{file.filename}' is not a valid #{kind} file"}, 403)
        end

        # Move file into place
        project.move_to_portfolio(file, name, kind) #returns details of file
      end #post

      desc "Remove a file from the portfolio files for a unit"
      params do
        requires :idx,   type: Integer,:desc => "The index of the file"
        requires :kind,  type: String, :desc => "The kind of file being removed: document, code, or image"
        requires :name,  type: String, :desc => "Name of file to remove"
      end
      delete '/submission/project/:id/portfolio' do
        project = Project.find(params[:id])

        if not authorise? current_user, project, :make_submission
          error!({"error" => "Not authorised to alter portfolio for project '#{params[:id]}'"}, 401)
        end

        idx = params[:idx]
        name = params[:name]
        kind = params[:kind]

        # Remove file
        project.remove_portfolio_file(idx, kind, name) #returns details of file
        nil
      end

      
      desc "Retrieve submission document included for the task id"
      get '/submission/project/:id/portfolio' do
        project = Project.find(params[:id])

        if not authorise? current_user, project, :get_submission
          error!({"error" => "Not authorised to download portfolio for project '#{params[:id]}'"}, 401)
        end

        evidence_loc = task.portfolio_evidence
        student = task.project.student
        unit = task.project.unit
        
        if evidence_loc.nil? || task.processing_pdf
          error!({"error" => "No submission under task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        
        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{task.task_definition.abbreviation}.pdf"
        env['api.format'] = :binary

        File.read(evidence_loc)
      end # get
    end
  end
end