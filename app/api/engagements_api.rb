require 'grape'

class EngagementsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers FileStreamHelper

  before do
    authenticated?
  end

  helpers do
    def engagement_for(project)
      project.engagements.find(params[:id])
    end

    def validate_evidence!(attachment, evidence_url, remove_evidence: false)
      if remove_evidence && (attachment.present? || evidence_url.present?)
        error!({ error: 'Cannot remove evidence and provide replacement evidence together.' }, 400)
      end

      if attachment.present? && evidence_url.present?
        error!({ error: 'Provide either an attachment or an evidence URL, not both.' }, 400)
      end

      return nil if attachment.blank?

      error!({ error: 'Attachment is empty.' }, 400) if File.size?(attachment['tempfile'].path).blank?
      if File.size?(attachment['tempfile'].path) >= 30_000_000
        error!({ error: 'Attachment exceeds the maximum attachment size of 30MB.' }, 400)
      end

      image_result = FileHelper.accept_file(attachment, 'engagement evidence image', 'image')
      return 'image' if image_result[:accepted]

      pdf_result = FileHelper.accept_file(attachment, 'engagement evidence PDF', 'document')
      return 'pdf' if pdf_result[:accepted]

      error!({ error: "File is not an acceptable image or PDF: #{pdf_result[:msg]}" }, 400)
    end
  end

  desc 'Get engagements for a project'
  get '/projects/:project_id/engagements' do
    project = Project.find(params[:project_id])
    error!({ error: 'You do not have permission to view these engagements.' }, 403) unless authorise?(current_user, project, :get_engagements)

    engagements = project.engagements
                         .includes(:user, :engagement_comments)
                         .order(:occurred_at, :created_at)
    present engagements, with: Entities::EngagementEntity
  end

  desc 'Get an engagement for a project'
  get '/projects/:project_id/engagements/:id' do
    project = Project.find(params[:project_id])
    error!({ error: 'You do not have permission to view this engagement.' }, 403) unless authorise?(current_user, project, :get_engagements)

    engagement = project.engagements
                        .includes(:user, engagement_comments: :user)
                        .find(params[:id])
    present engagement, with: Entities::EngagementDetailEntity
  end

  desc 'Create an engagement for a project'
  params do
    requires :engagement_type, type: String
    requires :note, type: String
    requires :occurred_at, type: DateTime
    optional :evidence_url, type: String
    optional :attachment, type: File
  end
  post '/projects/:project_id/engagements' do
    project = Project.find(params[:project_id])
    error!({ error: 'You do not have permission to create an engagement.' }, 403) unless authorise?(current_user, project, :create_engagement)

    attachment = params[:attachment]
    attachment_type = validate_evidence!(attachment, params[:evidence_url])

    engagement = project.engagements.create!(
      user: current_user,
      engagement_type: params[:engagement_type],
      note: params[:note],
      occurred_at: params[:occurred_at],
      evidence_url: attachment.present? ? nil : params[:evidence_url]
    )

    engagement.replace_attachment(attachment, attachment_type) if attachment.present?
    present engagement, with: Entities::EngagementDetailEntity
  rescue StandardError
    engagement&.destroy
    raise
  end

  desc 'Update an engagement for a project'
  params do
    optional :engagement_type, type: String
    optional :note, type: String
    optional :occurred_at, type: DateTime
    optional :evidence_url, type: String
    optional :attachment, type: File
    optional :remove_evidence, type: Boolean, default: false
  end
  put '/projects/:project_id/engagements/:id' do
    project = Project.find(params[:project_id])
    engagement = engagement_for(project)

    can_edit = authorise?(current_user, project, :edit_engagement) && engagement.user_id == current_user.id
    error!({ error: 'You do not have permission to edit this engagement.' }, 403) unless can_edit

    attachment = params[:attachment]
    evidence_url = params.key?(:evidence_url) ? params[:evidence_url] : nil
    attachment_type = validate_evidence!(
      attachment,
      evidence_url,
      remove_evidence: params[:remove_evidence]
    )

    attributes = {}
    attributes[:engagement_type] = params[:engagement_type] if params.key?(:engagement_type)
    attributes[:note] = params[:note] if params.key?(:note)
    attributes[:occurred_at] = params[:occurred_at] if params.key?(:occurred_at)

    if params[:remove_evidence]
      engagement.remove_attachment
      engagement.evidence_url = nil
    elsif attachment.present?
      engagement.assign_attributes(attributes)
      engagement.replace_attachment(attachment, attachment_type)
      attributes = {}
    elsif params.key?(:evidence_url)
      engagement.remove_attachment
      engagement.evidence_url = evidence_url
    end

    engagement.update!(attributes)
    present engagement.reload, with: Entities::EngagementDetailEntity
  end

  desc 'Delete an engagement for a project'
  delete '/projects/:project_id/engagements/:id' do
    project = Project.find(params[:project_id])
    engagement = engagement_for(project)
    error!({ error: 'You do not have permission to delete this engagement.' }, 403) unless authorise?(current_user, project.unit, :delete_engagement)

    engagement.destroy!
    present engagement.destroyed?, with: Grape::Presenters::Presenter
  end

  desc 'Get evidence attached to an engagement'
  params do
    optional :as_attachment, type: Boolean, default: false
  end
  get '/projects/:project_id/engagements/:id/attachment' do
    project = Project.find(params[:project_id])
    error!({ error: 'You do not have permission to view this evidence.' }, 403) unless authorise?(current_user, project, :get_engagements)

    engagement = engagement_for(project)
    error!({ error: 'No attachment for this engagement.' }, 404) unless engagement.attachment?
    error!({ error: 'File missing.' }, 404) unless File.exist?(engagement.attachment_path)

    content_type engagement.attachment_mime_type
    env['api.format'] = :binary
    if params[:as_attachment]
      header['Content-Disposition'] = "attachment; filename=#{engagement.attachment_file_name}"
    end

    stream_file engagement.attachment_path
  end

  desc 'Add a comment to an engagement'
  params do
    requires :comment, type: String
    optional :reply_to_id, type: Integer
  end
  post '/projects/:project_id/engagements/:id/comments' do
    project = Project.find(params[:project_id])
    error!({ error: 'You do not have permission to comment on this engagement.' }, 403) unless authorise?(current_user, project, :comment_engagement)

    engagement = engagement_for(project)
    reply_to = engagement.engagement_comments.find(params[:reply_to_id]) if params[:reply_to_id].present?
    comment = engagement.engagement_comments.create!(
      user: current_user,
      comment: params[:comment],
      reply_to: reply_to
    )
    present comment, with: Entities::EngagementCommentEntity
  end

  desc 'Update an engagement comment'
  params do
    requires :comment, type: String
  end
  put '/projects/:project_id/engagements/:id/comments/:comment_id' do
    project = Project.find(params[:project_id])
    error!({ error: 'You do not have permission to comment on this engagement.' }, 403) unless authorise?(current_user, project, :comment_engagement)

    engagement = engagement_for(project)
    comment = engagement.engagement_comments.find(params[:comment_id])
    error!({ error: 'You can only edit your own comments.' }, 403) unless comment.user_id == current_user.id
    if comment.created_at < 10.minutes.ago
      error!({ error: 'Comments can only be edited within 10 minutes of being created.' }, 403)
    end

    comment.update!(comment: params[:comment])
    present comment, with: Entities::EngagementCommentEntity
  end

  desc 'Delete an engagement comment'
  delete '/projects/:project_id/engagements/:id/comments/:comment_id' do
    project = Project.find(params[:project_id])
    engagement = engagement_for(project)
    comment = engagement.engagement_comments.find(params[:comment_id])

    can_delete_own = comment.user_id == current_user.id &&
                     authorise?(current_user, project, :comment_engagement)
    can_delete_any = authorise?(current_user, project.unit, :delete_engagement)
    error!({ error: 'You do not have permission to delete this comment.' }, 403) unless can_delete_own || can_delete_any

    comment.destroy!
    present comment.destroyed?, with: Grape::Presenters::Presenter
  end
end
