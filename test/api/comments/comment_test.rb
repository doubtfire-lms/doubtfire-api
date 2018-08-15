require 'test_helper'

class CommentTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_student_post_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

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
        author: {"id" => user.id}, 
        recipient: {"id" => project.main_tutor.id}
    }

    # check each is the same
    assert_json_matches_model last_response_body, expected_response, ["comment", "has_attachment", "type", "is_new"]
    assert_json_matches_model last_response_body["author"], expected_response[:author], ["id"]
    assert_json_matches_model last_response_body["recipient"], expected_response[:recipient], ["id"]
  end

  def test_student_post_image_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: Rack::Test::UploadedFile.new('test_files/submissions/Deakin_Logo.jpeg', 'image/jpeg') }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, "one comment added"

    new_comment = TaskComment.last

    assert_equal "image comment", new_comment.comment, "last comment has message"
    assert File.exists?(new_comment.attachment_path)
  end

  def test_post_comment_empty_attachment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    comment_data = { attachment: Rack::Test::UploadedFile.new('test_files/submissions/boo.png', 'image/png') }

    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", user), comment_data

    assert_equal 500, last_response.status

    assert_equal pre_count, TaskComment.count, "No comment should be created"
    assert_equal "Attachment is empty.", last_response_body["error"]
  end


end
