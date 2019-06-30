class DiscussionCommentSerializer < ActiveModel::Serializer
  attributes :id, :task_comment_id, :status, :time_completed, :time_started, :updated_at
  def status
    object.status
  end

    # created_at: "2019-06-28T08:41:24.471Z"
    # id: 1
    # task_comment_id: 33
    # time_completed: null
    # time_started: "2019-06-30T13:07:05.424Z"
    # updated_at: "2019-06-30T13:07:05.425Z"

  def author
    {
      id: object.user.id,
      name: object.user.name,
      email: object.user.email
    }
  end

  def recipient
    {
      id: object.recipient.id,
      name: object.recipient.name,
      email: object.user.email
    }
  end
end
