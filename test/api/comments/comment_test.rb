require 'test_helper'

class CommentTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_student_post_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first
    tutor = project.tutor_for(task_definition)

    pre_count = TaskComment.count

    comment_data = { comment: "Hello World" }

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 201, last_response.status

    assert_equal "Hello World", TaskComment.last.comment, "last comment has message"
    assert_equal pre_count + 1, TaskComment.count, "one comment added"

    expected_response = {
      "comment" => "Hello World",
      "has_attachment" => false,
      "type" => "text",
      "is_new" => false,
      author: { "id" => user.id },
      recipient: { "id" => tutor.id }
    }

    # check each is the same
    assert_json_matches_model last_response_body, expected_response, %w(comment has_attachment type is_new)
    assert_json_matches_model last_response_body["author"], expected_response[:author], ["id"]
    assert_json_matches_model last_response_body["recipient"], expected_response[:recipient], ["id"]
  end

  def test_replying_to_comments
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first
    tutor = project.tutor_for(task_definition)

    comment_data = { comment: "Hello World" }

    # Post original comment and check that it was successful
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data
    assert_equal 201, last_response.status

    expected_response = {
      "comment" => "Responding!",
      "has_attachment" => false,
      "type" => "text",
      "is_new" => false,
      "reply_to" => TaskComment.last.id,
      author: { "id" => user.id },
      recipient: { "id" => tutor.id }
    }

    # Student responding to self
    comment_data = { comment: "Responding!", reply_to: TaskComment.last.id }
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data
    assert_equal 201, last_response.status
    assert_json_matches_model last_response_body, expected_response, %w(comment type is_new reply_to)

    expected_response = {
      "comment" => "Responding again!",
      "has_attachment" => false,
      "type" => "text",
      "is_new" => false,
      "reply_to" => TaskComment.last.id,
      author: { "id" => user.id },
      recipient: { "id" => tutor.id }
    }
    # Tutor responding to student
    comment_data = { comment: "Responding again!", reply_to: TaskComment.last.id }
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", tutor), comment_data
    assert_equal 201, last_response.status

    # check each is the same
    assert_json_matches_model last_response_body, expected_response, %w(comment type is_new reply_to)
  end

  def test_student_post_reply_to_invalid_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    comment_data = { comment: "Responding!", reply_to: -1 }

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 404, last_response.status
  end

  def test_student_post_image_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: upload_file("test_files/submissions/Deakin_Logo.jpeg", "image/jpeg") }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, "one comment added"

    new_comment = TaskComment.last

    assert_equal "image comment", new_comment.comment, "last comment has message"
    assert File.exist?(new_comment.attachment_path)

    new_comment.destroy
  end

  def test_student_post_gif_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: upload_file("test_files/submissions/unbelievable.gif", "image/gif") }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, "one comment added"

    new_comment = TaskComment.last

    assert_equal "image comment", new_comment.comment, "last comment has message"
    assert File.exist?(new_comment.attachment_path)
    assert_equal ".gif", new_comment.attachment_extension, "attachment is a gif"

    new_comment.destroy
  end

  def test_student_post_pdf_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: upload_file("test_files/submissions/00_question.pdf", "application/pdf") }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, "one comment added"

    new_comment = TaskComment.last

    assert_equal "pdf document", new_comment.comment, "last comment has message"
    assert File.exist?(new_comment.attachment_path)
    assert_equal ".pdf", new_comment.attachment_extension, "attachment is a pdf"

    new_comment.destroy
  end

  def test_comment_attachments_deleted
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: upload_file("test_files/submissions/00_question.pdf", "application/pdf") }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, "one comment added"

    new_comment = TaskComment.last

    assert File.exist?(new_comment.attachment_path)

    new_comment.destroy
    assert_not File.exist?(new_comment.attachment_path)
  end

  def test_post_comment_empty_attachment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: upload_file("test_files/submissions/boo.png", "image/png") }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 500, last_response.status

    assert_equal pre_count, TaskComment.count, "No comment should be created"
    assert_equal "Attachment is empty.", last_response_body["error"]
  end

  def test_read_receipts_for_task_status_comments
    project = Project.first
    user = project.student
    unit = project.unit

    td = TaskDefinition.new(unit_id: unit.id,
                            tutorial_stream: unit.tutorial_streams.first,
                            name: "test_read_receipts_for_task_status_comments",
                            description: "test_read_receipts_for_task_status_comments",
                            weighting: 4,
                            target_grade: 0,
                            start_date: Time.zone.now - 2.weeks,
                            target_date: Time.zone.now + 1.week,
                            due_date: Time.zone.now + 2.weeks,
                            abbreviation: "test_read_receipts_for_task_status_comments",
                            restrict_status_updates: false,
                            upload_requirements: [ ],
                            plagiarism_warn_pct: 0.8,
                            is_graded: false,
                            max_quality_pts: 0)
    td.save!

    data_to_post = {
      trigger: "ready_to_mark"
    }

    # Make a submission for this student
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/submission", user), data_to_post
    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.ready_to_mark, task.task_status

    tutor = project.tutor_for(td)

    tc = task.comments.last
    assert tc.comments_read_receipts.count >= 2, "Error: expected multiple read receipts."
    assert tc.comments_read_receipts.where(user: tutor).count == 1, "Error: tutor has not read the comment"

    td.destroy!

    # read_reciept = CommentsReadReceipts.find_by(user: tutor, task_comment: tc)
  end
end
