require 'test_helper'

class EngagementTest < ActiveSupport::TestCase
  def test_requires_core_attributes
    engagement = Engagement.new

    assert_not engagement.valid?
    assert_includes engagement.errors[:project], 'must exist'
    assert_includes engagement.errors[:user], 'must exist'
    assert_includes engagement.errors[:engagement_type], "can't be blank"
    assert_includes engagement.errors[:note], "can't be blank"
    assert_includes engagement.errors[:occurred_at], "can't be blank"
  end

  def test_accepts_free_form_engagement_types_and_trims_text
    engagement = FactoryBot.build(
      :engagement,
      engagement_type: '  negative  ',
      note: '  Missed an agreed check-in.  '
    )

    assert engagement.valid?
    assert_equal 'negative', engagement.engagement_type
    assert_equal 'Missed an agreed check-in.', engagement.note
  end

  def test_validates_evidence_url
    engagement = FactoryBot.build(:engagement, evidence_url: 'ftp://example.com/evidence')

    assert_not engagement.valid?
    assert_includes engagement.errors[:evidence_url], 'must be a valid HTTP or HTTPS URL'

    engagement.evidence_url = 'https://example.com/evidence'
    assert engagement.valid?
  end

  def test_rejects_attachment_and_url_together
    engagement = FactoryBot.build(
      :engagement,
      evidence_url: 'https://example.com/evidence',
      content_type: 'image',
      attachment_extension: '.jpg'
    )

    assert_not engagement.valid?
    assert_includes engagement.errors[:base], 'An engagement can have either an evidence URL or an attachment, not both'
  end

  def test_destroy_removes_comments_and_attachment
    engagement = FactoryBot.create(
      :engagement,
      content_type: 'image',
      attachment_extension: '.jpg'
    )
    comment = FactoryBot.create(:engagement_comment, engagement: engagement)
    FileUtils.touch(engagement.attachment_path)

    attachment_path = engagement.attachment_path
    engagement.destroy!

    assert_not File.exist?(attachment_path)
    assert_nil EngagementComment.find_by(id: comment.id)
  end

  def test_project_destroy_removes_engagement
    engagement = FactoryBot.create(:engagement)

    engagement.project.tutorial_enrolments.destroy_all
    engagement.project.destroy!

    assert_nil Engagement.find_by(id: engagement.id)
  end

  def test_comment_reply_must_belong_to_same_engagement
    engagement = FactoryBot.create(:engagement)
    other_engagement = FactoryBot.create(:engagement)
    original_comment = FactoryBot.create(:engagement_comment, engagement: engagement)
    reply = FactoryBot.build(
      :engagement_comment,
      engagement: other_engagement,
      reply_to: original_comment
    )

    assert_not reply.valid?
    assert_includes reply.errors[:reply_to], 'must belong to the same engagement'
  end

  def test_author_cannot_be_deleted_while_engagement_exists
    engagement = FactoryBot.create(:engagement)

    assert_raises(ActiveRecord::DeleteRestrictionError) do
      engagement.user.destroy!
    end
    assert Engagement.exists?(engagement.id)
  end
end
