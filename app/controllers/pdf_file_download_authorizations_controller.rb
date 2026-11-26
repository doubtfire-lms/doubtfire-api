class PdfFileDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include DownloadAuthorization

  # Each entry maps one download URL to the method that checks permissions and
  # returns the file. Handlers receive the MatchData for their own pattern.
  ROUTES = {
    %r{\A/api/units/(?<unit_id>\d+)/task_definitions/(?<task_definition_id>\d+)/task_pdf(?:\.json)?(?:\?(?<query>.*))?\z} => :task_sheet_download,
    %r{\A/api/units/(?<unit_id>\d+)/task_definitions/(?<task_definition_id>\d+)/jplag_report(?:\?(?<query>.*))?\z} => :jplag_report_download,
    %r{\A/api/submission/project/(?<project_id>\d+)/portfolio(?:\?(?<query>.*))?\z} => :portfolio_download,
    %r{\A/api/tasks/(?<task_id>\d+)/similarities/(?<similarity_id>\d+)/contents/(?<index>\d+)(?:\?(?<query>.*))?\z} => :similarity_download,
    %r{\A/api/projects/(?<project_id>\d+)/task_def_id/(?<task_definition_id>\d+)/comments/(?<comment_id>\d+)(?:\?(?<query>.*))?\z} => :comment_download,
    %r{\A/api/projects/(?<project_id>\d+)/engagements/(?<engagement_id>\d+)/attachment(?:\?(?<query>.*))?\z} => :engagement_download
  }.freeze

  def show
    return head :not_found unless trusted_caddy_request?
    return head :unauthorized unless download_header_user

    download = locate_download(original_uri)
    return head download unless download.is_a?(Hash)

    _resolved, relative_path = authorised_file_path(download[:path])
    return head :not_found unless relative_path

    serve_via_caddy(
      relative_path: relative_path,
      filename: FileHelper.sanitized_filename(download[:filename]),
      content_type: download[:content_type],
      disposition: attachment_requested?(download[:query]) ? 'attachment' : 'inline'
    )
  end

  private

  def locate_download(uri)
    ROUTES.each do |pattern, handler|
      route = pattern.match(uri)
      return send(handler, route) if route
    end

    :not_found
  end

  def task_sheet_download(route)
    unit = Unit.find_by(id: route[:unit_id])
    return :not_found unless unit

    task_definition = unit.task_definitions.find_by(id: route[:task_definition_id])
    return :not_found unless task_definition
    return :forbidden unless authorise?(current_user, unit, :get_unit)
    return :not_found unless task_definition.has_task_sheet?

    {
      path: task_definition.task_sheet(false),
      filename: "#{unit.code}-#{task_definition.abbreviation}.pdf",
      content_type: 'application/pdf',
      query: route[:query]
    }
  end

  def jplag_report_download(route)
    unit = Unit.find_by(id: route[:unit_id])
    return :not_found unless unit

    task_definition = unit.task_definitions.find_by(id: route[:task_definition_id])
    return :not_found unless task_definition
    return :forbidden unless authorise?(current_user, unit, :download_jplag_report)

    {
      path: FileHelper.task_jplag_report_path(unit, task_definition),
      filename: "#{unit.code}-#{task_definition.abbreviation}-jplag-report.jplag",
      content_type: 'application/octet-stream',
      query: route[:query]
    }
  end

  def portfolio_download(route)
    project = Project.find_by(id: route[:project_id])
    return :not_found unless project
    return :forbidden unless authorise?(current_user, project, :get_submission)

    {
      path: project.portfolio_path,
      filename: "#{project.unit.code}-#{project.student.username}-portfolio.pdf",
      content_type: 'application/pdf',
      query: route[:query]
    }
  end

  def similarity_download(route)
    task = Task.find_by(id: route[:task_id])
    return :not_found unless task
    return :forbidden unless authorise?(current_user, task, :view_plagiarism)

    similarity = task.task_similarities.find_by(id: route[:similarity_id])

    case similarity
    when MossTaskSimilarity then moss_similarity_download(similarity, route)
    when TiiTaskSimilarity then tii_similarity_download(similarity, route)
    else :not_found
    end
  end

  def moss_similarity_download(similarity, route)
    selected = if route[:index] == '0'
                 similarity
               elsif route[:index] == '1' && authorise?(current_user, similarity.other_task, :view_plagiarism)
                 similarity.other_similarity
               end
    return :not_found unless selected

    {
      path: FileHelper.path_to_plagarism_html(selected),
      filename: "#{selected.student.username}_#{selected.other_student&.username}_#{selected.pct}.html",
      content_type: 'text/html',
      query: route[:query]
    }
  end

  def tii_similarity_download(similarity, route)
    {
      path: similarity.similarity_pdf_path,
      filename: "similarity-#{similarity.id}.pdf",
      content_type: 'application/pdf',
      query: route[:query]
    }
  end

  def comment_download(route)
    project = Project.find_by(id: route[:project_id])
    return :not_found unless project
    return :forbidden unless authorise?(current_user, project, :get)

    task_definition = project.unit.task_definitions.find_by(id: route[:task_definition_id])
    return :not_found unless task_definition

    task = project.task_for_task_definition(task_definition)
    return :not_found unless task

    comment = task.comments.find_by(id: route[:comment_id])
    return :not_found unless comment && %w[audio image pdf].include?(comment.content_type)

    SessionTracker.record_assessment_activity(
      action: 'get-comment-attachment',
      user: current_user,
      project: project,
      ip_address: request.ip,
      task: task
    )

    attachment_download(comment, route[:query])
  end

  def engagement_download(route)
    project = Project.find_by(id: route[:project_id])
    return :not_found unless project
    return :forbidden unless authorise?(current_user, project, :get_engagements)

    engagement = project.engagements.find_by(id: route[:engagement_id])
    return :not_found unless engagement&.attachment?

    attachment_download(engagement, route[:query])
  end

  def attachment_download(record, query)
    {
      path: record.attachment_path,
      filename: record.attachment_file_name,
      content_type: record.attachment_mime_type,
      query: query
    }
  end
end
