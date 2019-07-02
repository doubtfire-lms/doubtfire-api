class DiscussionCommentSerializer < TaskCommentSerializer
  attributes :id, :status, :time_discussion_completed, :time_discussion_started
  def status
    object.status
  end
end
