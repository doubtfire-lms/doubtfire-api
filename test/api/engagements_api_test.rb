require 'test_helper'

class EngagementsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def setup
    @unit = FactoryBot.create(:unit, with_students: false)
    @student = FactoryBot.create(:user, :student)
    @project = @unit.enrol_student(@student, nil)
    @tutor = FactoryBot.create(:user, :tutor)
    @unit.employ_staff(@tutor, Role.tutor)
    @convenor = @unit.main_convenor_user
  end

  def engagement_params(overrides = {})
    {
      engagement_type: 'attendance',
      note: 'Attended the weekly discussion.',
      occurred_at: Time.zone.now.iso8601
    }.merge(overrides)
  end

  def create_engagement(user: @tutor, overrides: {})
    add_auth_header_for(user: user)
    post_json "/api/projects/#{@project.id}/engagements", engagement_params(overrides)
    assert_equal 201, last_response.status, last_response.body
    Engagement.find(last_response_body['id'])
  end

  def test_tutor_can_create_and_student_can_read_engagements
    later = create_engagement(overrides: { engagement_type: 'forum', occurred_at: 1.day.from_now.iso8601 })
    earlier = create_engagement(overrides: { engagement_type: 'negative', occurred_at: 1.day.ago.iso8601 })

    add_auth_header_for(user: @student)
    get "/api/projects/#{@project.id}/engagements"

    assert_equal 200, last_response.status
    assert_equal [earlier.id, later.id], (last_response_body.map { |engagement| engagement['id'] })
    assert_equal 'negative', last_response_body.first['engagement_type']
    assert_equal @tutor.id, last_response_body.first.dig('user', 'id')
  end

  def test_student_and_unrelated_tutor_cannot_create_engagements
    add_auth_header_for(user: @student)
    post_json "/api/projects/#{@project.id}/engagements", engagement_params
    assert_equal 403, last_response.status

    unrelated_tutor = FactoryBot.create(:user, :tutor)
    add_auth_header_for(user: unrelated_tutor)
    post_json "/api/projects/#{@project.id}/engagements", engagement_params
    assert_equal 403, last_response.status
  end

  def test_only_author_with_current_teaching_access_can_edit
    engagement = create_engagement
    other_tutor = FactoryBot.create(:user, :tutor)
    @unit.employ_staff(other_tutor, Role.tutor)

    add_auth_header_for(user: other_tutor)
    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}",
      { note: 'Changed by another tutor.' }
    )
    assert_equal 403, last_response.status

    add_auth_header_for(user: @tutor)
    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}",
      { note: 'Corrected note.', occurred_at: 2.days.ago.iso8601 }
    )
    assert_equal 200, last_response.status
    assert_equal 'Corrected note.', engagement.reload.note

    @unit.unit_role_for(@tutor).destroy!
    assert Engagement.exists?(engagement.id)

    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}",
      { note: 'Changed after role removal.' }
    )
    assert_equal 403, last_response.status
    assert_equal 'Corrected note.', engagement.reload.note
  end

  def test_only_convenor_can_delete
    engagement = create_engagement

    add_auth_header_for(user: @tutor)
    delete "/api/projects/#{@project.id}/engagements/#{engagement.id}"
    assert_equal 403, last_response.status

    add_auth_header_for(user: @convenor)
    delete "/api/projects/#{@project.id}/engagements/#{engagement.id}"
    assert_equal 200, last_response.status
    assert_nil Engagement.find_by(id: engagement.id)
  end

  def test_student_and_teaching_staff_can_comment
    engagement = create_engagement

    add_auth_header_for(user: @student)
    post_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments",
      { comment: 'I have added the supporting context.' }
    )
    assert_equal 201, last_response.status
    assert_equal @student.id, last_response_body.dig('user', 'id')

    add_auth_header_for(user: @tutor)
    post_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments",
      { comment: 'Thanks, this clarifies the evidence.' }
    )
    assert_equal 201, last_response.status

    unrelated_student = FactoryBot.create(:user, :student)
    add_auth_header_for(user: unrelated_student)
    post_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments",
      { comment: 'Unrelated comment.' }
    )
    assert_equal 403, last_response.status

    add_auth_header_for(user: @student)
    get "/api/projects/#{@project.id}/engagements/#{engagement.id}"
    assert_equal 200, last_response.status
    assert_equal 2, last_response_body['comments'].length
    assert_equal(
      ['I have added the supporting context.', 'Thanks, this clarifies the evidence.'],
      last_response_body['comments'].map { |comment| comment['comment'] }
    )
  end

  def test_comment_can_reply_to_comment_in_same_engagement
    engagement = create_engagement

    add_auth_header_for(user: @student)
    post_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments",
      { comment: 'Original comment.' }
    )
    assert_equal 201, last_response.status
    original_comment_id = last_response_body['id']

    add_auth_header_for(user: @tutor)
    post_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments",
      { comment: 'Reply comment.', reply_to_id: original_comment_id }
    )
    assert_equal 201, last_response.status
    assert_equal original_comment_id, last_response_body['reply_to_id']

    get "/api/projects/#{@project.id}/engagements/#{engagement.id}"
    assert_equal original_comment_id, last_response_body['comments'].last['reply_to_id']
  end

  def test_comment_cannot_reply_to_comment_in_another_engagement
    engagement = create_engagement
    other_engagement = create_engagement(overrides: { note: 'Another engagement.' })
    original_comment = engagement.engagement_comments.create!(
      user: @student,
      comment: 'Comment on the first engagement.'
    )

    add_auth_header_for(user: @tutor)
    post_json(
      "/api/projects/#{@project.id}/engagements/#{other_engagement.id}/comments",
      { comment: 'Invalid reply.', reply_to_id: original_comment.id }
    )
    assert_equal 404, last_response.status
  end

  def test_comment_author_can_edit_within_ten_minutes
    engagement = create_engagement
    comment = engagement.engagement_comments.create!(user: @student, comment: 'Original comment.')

    add_auth_header_for(user: @student)
    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments/#{comment.id}",
      { comment: 'Updated comment.' }
    )

    assert_equal 200, last_response.status
    assert_equal 'Updated comment.', comment.reload.comment
  end

  def test_comment_cannot_be_edited_after_ten_minutes_or_by_another_user
    engagement = create_engagement
    comment = engagement.engagement_comments.create!(user: @student, comment: 'Original comment.')

    add_auth_header_for(user: @tutor)
    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments/#{comment.id}",
      { comment: 'Tutor edit.' }
    )
    assert_equal 403, last_response.status

    comment.update_column(:created_at, 11.minutes.ago)
    add_auth_header_for(user: @student)
    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments/#{comment.id}",
      { comment: 'Late edit.' }
    )
    assert_equal 403, last_response.status
    assert_equal 'Original comment.', comment.reload.comment
  end

  def test_comment_author_and_convenor_can_delete
    engagement = create_engagement
    student_comment = engagement.engagement_comments.create!(
      user: @student,
      comment: 'Student comment.'
    )

    add_auth_header_for(user: @tutor)
    delete "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments/#{student_comment.id}"
    assert_equal 403, last_response.status

    add_auth_header_for(user: @student)
    delete "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments/#{student_comment.id}"
    assert_equal 200, last_response.status
    assert_not EngagementComment.exists?(student_comment.id)

    tutor_comment = engagement.engagement_comments.create!(user: @tutor, comment: 'Tutor comment.')
    add_auth_header_for(user: @convenor)
    delete "/api/projects/#{@project.id}/engagements/#{engagement.id}/comments/#{tutor_comment.id}"
    assert_equal 200, last_response.status
    assert_not EngagementComment.exists?(tutor_comment.id)
  end

  def test_rejects_file_and_url_together
    add_auth_header_for(user: @tutor)
    data = engagement_params(
      evidence_url: 'https://example.com/evidence',
      attachment: upload_file('test_files/submissions/boo.png', 'image/png')
    )

    post "/api/projects/#{@project.id}/engagements", data

    assert_equal 400, last_response.status
    assert_equal 0, @project.engagements.count
  end

  def test_image_attachment_can_be_retrieved_and_replaced_with_url
    add_auth_header_for(user: @tutor)
    data = engagement_params(
      attachment: upload_file('test_files/submissions/Deakin_Logo.jpeg', 'image/jpeg')
    )

    post "/api/projects/#{@project.id}/engagements", data
    assert_equal 201, last_response.status, last_response.body

    engagement = Engagement.find(last_response_body['id'])
    assert engagement.attachment?
    assert File.exist?(engagement.attachment_path)

    add_auth_header_for(user: @student)
    get "/api/projects/#{@project.id}/engagements/#{engagement.id}/attachment"
    assert_equal 200, last_response.status

    add_auth_header_for(user: @tutor)
    old_attachment_path = engagement.attachment_path
    put_json(
      "/api/projects/#{@project.id}/engagements/#{engagement.id}",
      { evidence_url: 'https://example.com/replacement' }
    )
    assert_equal 200, last_response.status

    engagement.reload
    assert_not engagement.attachment?
    assert_not File.exist?(old_attachment_path)
    assert_equal 'https://example.com/replacement', engagement.evidence_url
  end

  def test_pdf_attachment_is_accepted_and_removed_with_project
    add_auth_header_for(user: @tutor)
    data = engagement_params(
      attachment: upload_file('test_files/submissions/00_question.pdf', 'application/pdf')
    )

    post "/api/projects/#{@project.id}/engagements", data
    assert_equal 201, last_response.status, last_response.body

    engagement = Engagement.find(last_response_body['id'])
    assert_equal 'pdf', engagement.content_type
    attachment_path = engagement.attachment_path
    assert File.exist?(attachment_path)

    @project.tutorial_enrolments.destroy_all
    @project.destroy!

    assert_nil Engagement.find_by(id: engagement.id)
    assert_not File.exist?(attachment_path)
  end
end
