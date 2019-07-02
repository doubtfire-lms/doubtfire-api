class DiscussionCommentSerializer < TaskCommentSerializer
  attributes :id, :status, :time_discussion_completed, :time_discussion_started, :number_of_prompts
  def status
    object.status
  end
end
