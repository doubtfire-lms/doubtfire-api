require "test_helper"

class DiscussionCommentTest < ActiveSupport::TestCase
  def discussion_comment
    @discussion_comment ||= DiscussionComment.new
  end

  def test_valid
    assert discussion_comment.valid?
  end
end
