require 'pathname'

class PdfFileDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers

  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze

  TASK_SHEET_PATH = %r{\A/api/units/(?<unit_id>\d+)/task_definitions/(?<task_definition_id>\d+)/task_pdf(?:\.json)?(?:\?(?<query>.*))?\z}
  PORTFOLIO_PATH = %r{\A/api/submission/project/(?<project_id>\d+)/portfolio(?:\?(?<query>.*))?\z}
  SIMILARITY_PATH = %r{\A/api/tasks/(?<task_id>\d+)/similarities/(?<similarity_id>\d+)/contents/(?<index>\d+)(?:\?(?<query>.*))?\z}
  COMMENT_PATH = %r{\A/api/projects/(?<project_id>\d+)/task_def_id/(?<task_definition_id>\d+)/comments/(?<comment_id>\d+)(?:\?(?<query>.*))?\z}
  ENGAGEMENT_PATH = %r{\A/api/projects/(?<project_id>\d+)/engagements/(?<engagement_id>\d+)/attachment(?:\?(?<query>.*))?\z}

  def show
    return head :not_found unless trusted_caddy_request?
    return head :unauthorized unless authenticated_for_download?

    status, download = find_download(request.headers[ORIGINAL_URI_HEADER].to_s)
    return head status unless status == :ok

    _resolved_path, relative_path = authorised_file_path(download[:path])
    return head :not_found unless relative_path

    disposition = ActionDispatch::Http::ContentDisposition.format(
      disposition: attachment_requested?(download[:query]) ? 'attachment' : 'inline',
      filename: FileHelper.sanitized_filename(download[:filename])
    )

    response.set_header('X-OnTrack-File', relative_path)
    response.set_header('X-OnTrack-Content-Disposition', disposition)
    response.set_header('X-OnTrack-Content-Type', download[:content_type])

    head :ok
  end

  private

  def trusted_caddy_request?
    expected = ENV.fetch('DF_CADDY_DOWNLOAD_AUTH_SECRET', '')
    provided = request.headers[INTERNAL_SECRET_HEADER].to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def authenticated_for_download?
    username, token = get_user_and_token_from(:header)
    user_auth_token_type(username, token, :general) == :valid
  end

  def find_download(uri)
    return task_sheet_download(Regexp.last_match) if TASK_SHEET_PATH.match(uri)
    return portfolio_download(Regexp.last_match) if PORTFOLIO_PATH.match(uri)
    return similarity_download(Regexp.last_match) if SIMILARITY_PATH.match(uri)
    return comment_download(Regexp.last_match) if COMMENT_PATH.match(uri)
    return engagement_download(Regexp.last_match) if ENGAGEMENT_PATH.match(uri)

    [:not_found, nil]
  end

  def task_sheet_download(route)
    unit = Unit.find_by(id: route[:unit_id])
    return [:not_found, nil] unless unit

    task_definition = unit.task_definitions.find_by(id: route[:task_definition_id])
    return [:not_found, nil] unless task_definition
    return [:forbidden, nil] unless authorise?(current_user, unit, :get_unit)
    return [:not_found, nil] unless task_definition.has_task_sheet?

    [:ok, {
      path: task_definition.task_sheet(false),
      filename: "#{unit.code}-#{task_definition.abbreviation}.pdf",
      content_type: 'application/pdf',
      query: route[:query]
    }]
  end

  def portfolio_download(route)
    project = Project.find_by(id: route[:project_id])
    return [:not_found, nil] unless project
    return [:forbidden, nil] unless authorise?(current_user, project, :get_submission)

    [:ok, {
      path: project.portfolio_path,
      filename: "#{project.unit.code}-#{project.student.username}-portfolio.pdf",
      content_type: 'application/pdf',
      query: route[:query]
    }]
  end

  def similarity_download(route)
    task = Task.find_by(id: route[:task_id])
    return [:not_found, nil] unless task
    return [:forbidden, nil] unless authorise?(current_user, task, :view_plagiarism)

    similarity = task.task_similarities.find_by(id: route[:similarity_id])
    return [:not_found, nil] unless similarity

    if similarity.is_a?(MossTaskSimilarity)
      moss_similarity_download(similarity, route)
    elsif similarity.is_a?(TiiTaskSimilarity)
      [:ok, {
        path: similarity.similarity_pdf_path,
        filename: "similarity-#{similarity.id}.pdf",
        content_type: 'application/pdf',
        query: route[:query]
      }]
    else
      [:not_found, nil]
    end
  end

  def moss_similarity_download(similarity, route)
    selected_similarity = if route[:index] == '0'
                            similarity
                          elsif route[:index] == '1' && authorise?(current_user, similarity.other_task, :view_plagiarism)
                            similarity.other_similarity
                          end
    return [:not_found, nil] unless selected_similarity

    [:ok, {
      path: FileHelper.path_to_plagarism_html(selected_similarity),
      filename: "#{selected_similarity.student.username}_#{selected_similarity.other_student&.username}_#{selected_similarity.pct}.html",
      content_type: 'text/html',
      query: route[:query]
    }]
  end

  def comment_download(route)
    project = Project.find_by(id: route[:project_id])
    return [:not_found, nil] unless project
    return [:forbidden, nil] unless authorise?(current_user, project, :get)

    task_definition = project.unit.task_definitions.find_by(id: route[:task_definition_id])
    return [:not_found, nil] unless task_definition

    task = project.task_for_task_definition(task_definition)
    return [:not_found, nil] unless task

    comment = task.comments.find_by(id: route[:comment_id])
    return [:not_found, nil] unless comment && %w[audio image pdf].include?(comment.content_type)

    SessionTracker.record_assessment_activity(
      action: 'get-comment-attachment',
      user: current_user,
      project: project,
      ip_address: request.ip,
      task: task
    )

    [:ok, {
      path: comment.attachment_path,
      filename: comment.attachment_file_name,
      content_type: comment.attachment_mime_type,
      query: route[:query]
    }]
  end

  def engagement_download(route)
    project = Project.find_by(id: route[:project_id])
    return [:not_found, nil] unless project
    return [:forbidden, nil] unless authorise?(current_user, project, :get_engagements)

    engagement = project.engagements.find_by(id: route[:engagement_id])
    return [:not_found, nil] unless engagement&.attachment?

    [:ok, {
      path: engagement.attachment_path,
      filename: engagement.attachment_file_name,
      content_type: engagement.attachment_mime_type,
      query: route[:query]
    }]
  end

  def attachment_requested?(query)
    ActiveModel::Type::Boolean.new.cast(Rack::Utils.parse_nested_query(query.to_s)['as_attachment'])
  end

  def authorised_file_path(file_path)
    return [nil, nil] if file_path.blank? || !File.file?(file_path)

    root = Pathname.new(Doubtfire::Application.config.student_work_dir).realpath
    resolved = Pathname.new(file_path).realpath
    return [nil, nil] unless resolved.to_s.start_with?("#{root}#{File::SEPARATOR}")

    [resolved, resolved.relative_path_from(root).to_s]
  rescue Errno::ENOENT, Errno::EACCES
    [nil, nil]
  end
end
