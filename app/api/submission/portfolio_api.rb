require 'grape'

module Submission
  class PortfolioApi < Grape::API
    helpers GenerateHelpers
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers FileStreamHelper

    before do
      authenticated?
    end

    desc "Upload documents for inclusion in a project's portfolio"
    params do
      requires :name,  type: String,                        desc: 'Name of the part being uploaded'
      requires :kind,  type: String,                        desc: 'The kind of file being uploaded: document, code, or image'
      requires :file0, type: File, desc: 'file 0.'
    end
    post '/submission/project/:id/portfolio' do
      project = Project.find(params[:id])

      unless authorise? current_user, project, :make_submission
        error!({ error: "Not authorised to submit portfolio for project '#{params[:id]}'" }, 401)
      end

      file = params[:file0]
      name = params[:name]
      kind = params[:kind]

      # Check that the file is OK to accept
      file_result = FileHelper.accept_file(file, name, kind)
      unless file_result[:accepted]
        error!({ error: "'#{file[:filename]}': #{file_result[:msg]}" }, 403)
      end

      # Move file into place
      result = project.move_to_portfolio(file, name, kind) # returns details of file

      present result, Grape::Presenters::Presenter
    end # post

    desc 'Remove a file from the portfolio files for a unit'
    params do
      optional :idx,   type: Integer, desc: 'The index of the file'
      optional :kind,  type: String, desc: 'The kind of file being removed: document, code, or image'
      optional :name,  type: String, desc: 'Name of file to remove'
      optional :confirm_late, type: Boolean, default: false, desc: 'Confirm deletion after the effective portfolio deadline'
    end
    delete '/submission/project/:id/portfolio' do
      project = Project.find(params[:id])
      deleting_whole_portfolio = params[:idx].nil? && params[:name].nil? && params[:kind].nil?

      if deleting_whole_portfolio
        unit_role = project.unit.unit_role_for(current_user)
        can_delete = project.user_id == current_user.id || unit_role&.role_id == Role.convenor_id
        unless can_delete
          error!({ error: "Not authorised to delete portfolio for project '#{params[:id]}'" }, 403)
        end
        if project.compile_portfolio?
          error!({ error: 'The portfolio is still compiling. Wait for compilation to finish before deleting it.' }, 409)
        end
        if project.portfolio_deadline_passed? && !params[:confirm_late]
          error!({
                   error: 'Deleting this portfolio requires confirmation because the effective portfolio deadline has passed.',
                   portfolio_late_confirmation_required: true,
                   effective_portfolio_deadline: project.effective_portfolio_deadline.iso8601,
                   effective_portfolio_deadline_timezone: project.effective_portfolio_deadline_timezone
                 }, 409)
        end

        project.update!({
                          portfolio_submission_date: nil,
                          portfolio_production_date: nil,
                          compile_portfolio: false
                        })
        project.remove_portfolio # returns details of file
      elsif !(params[:idx].nil? || params[:name].nil? || params[:kind].nil?)
        unless authorise? current_user, project, :make_submission
          error!({ error: "Not authorised to alter portfolio for project '#{params[:id]}'" }, 403)
        end

        idx = params[:idx]
        name = params[:name]
        kind = params[:kind]

        project.remove_portfolio_file(idx, kind, name) # returns details of file
      end

      nil
    end

    desc 'Retrieve portfolio for project with the given id'
    params do
      optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
    end
    get '/submission/project/:id/portfolio' do
      project = Project.find(params[:id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to download portfolio for project '#{params[:id]}'" }, 401)
      end

      evidence_loc = project.portfolio_path

      if evidence_loc.nil? || File.exist?(evidence_loc) == false
        evidence_loc = Rails.root.join('public/resources/FileNotFound.pdf')
        filename = 'FileNotFound.pdf'
      else
        filename = "#{project.unit.code}-#{project.student.username}-portfolio.pdf"
      end

      if params[:as_attachment]
        header['Content-Disposition'] = "attachment; filename=#{filename}"
      end

      # Set download headers...
      content_type 'application/pdf'
      env['api.format'] = :binary

      stream_file evidence_loc
    end # get

    # "Retrieve portfolios for a unit" done using controller
  end
end
