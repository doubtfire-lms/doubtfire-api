require 'test_helper'

class CommentTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_get_comments
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)

    add_auth_header_for user: user
    get "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments"

    assert_equal 200, last_response.status, last_response_body
    assert_equal 0, last_response_body.length, last_response_body.inspect

    task.add_text_comment(convenor, 'Hello World')
    task.add_text_comment(convenor, 'Message 2')
    task.add_text_comment(convenor, 'Last message')

    get "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments"

    assert_equal 200, last_response.status, last_response_body
    assert_equal 3, last_response_body.length, last_response_body.inspect

    keys = %w(id comment has_attachment type is_new reply_to_id author recipient created_at recipient_read_time)
    keys_test = %w(id comment reply_to_id)

    last_response_body.each do |resp|
      assert_json_limit_keys_to_exactly keys, resp
      comment = TaskComment.find(resp['id'])
      assert_json_matches_model comment, resp, keys_test
      assert resp['is_new'], resp.inspect
    end

    # Test they are now read...
    get "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments"

    assert_equal 200, last_response.status, last_response_body
    assert_equal 3, last_response_body.length, last_response_body.inspect

    keys = %w(id comment has_attachment type is_new reply_to_id author recipient created_at recipient_read_time)
    keys_test = %w(id comment reply_to_id)

    last_response_body.each do |resp|
      assert_json_limit_keys_to_exactly keys, resp
      comment = TaskComment.find(resp['id'])
      assert_json_matches_model comment, resp, keys_test
      refute resp['is_new'], resp.inspect
    end

    task.add_text_comment(user, 'Response')
  end

  def test_student_post_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first
    tutor = project.tutor_for(task_definition)

    pre_count = TaskComment.count

    comment_data = { comment: 'Hello World' }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    post_json "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 201, last_response.status

    assert_equal 'Hello World', TaskComment.last.comment, 'last comment has message'
    assert_equal pre_count + 1, TaskComment.count, 'one comment added'

    expected_response = {
      'comment' => 'Hello World',
      'has_attachment' => false,
      'type' => 'text',
      'is_new' => false,
      author: { 'id' => user.id },
      recipient: { 'id' => tutor.id }
    }

    # check each is the same
    assert_json_matches_model expected_response, last_response_body, %w(comment has_attachment type is_new)
    assert_json_matches_model expected_response[:author], last_response_body['author'], ['id']
    assert_json_matches_model expected_response[:recipient], last_response_body['recipient'], ['id']
  end

  def test_replying_to_comments
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit, with_students: true, student_count: 2)
    unit.employ_staff(User.first, Role.convenor)
    project = FactoryBot.create(:project, unit: unit, campus: campus)
    user = project.student
    task_definition = unit.task_definitions.first
    tutor = project.tutor_for(task_definition)

    comment_data = { comment: 'Hello World' }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Post original comment and check that it was successful
    post_json "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data
    assert_equal 201, last_response.status

    expected_response = {
      'comment' => 'Responding!',
      'has_attachment' => false,
      'type' => 'text',
      'reply_to_id' => TaskComment.last.id,
      author: { 'id' => user.id },
      recipient: { 'id' => tutor.id }
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Student responding to self
    comment_data = { comment: 'Responding!', reply_to_id: TaskComment.last.id }
    post_json "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data
    assert_equal 201, last_response.status
    assert_json_matches_model expected_response, last_response_body, %w(comment type reply_to_id)

    expected_response = {
      'comment' => 'Responding again!',
      'has_attachment' => false,
      'type' => 'text',
      'reply_to_id' => TaskComment.last.id,
      author: { 'id' => user.id },
      recipient: { 'id' => tutor.id }
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Tutor responding to student
    comment_data = { comment: 'Responding again!', reply_to_id: TaskComment.last.id }
    post_json "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data
    assert_equal 201, last_response.status

    # check each is the same
    assert_json_matches_model expected_response, last_response_body, %w(comment type reply_to_id)
  end

  def test_student_post_reply_to_invalid_comment
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit, with_students: true, student_count: 2)
    unit.employ_staff(User.first, Role.convenor)
    project = FactoryBot.create(:project, unit: unit, campus: campus)
    user = project.student
    task_definition = unit.task_definitions.first
    tutor = project.tutor_for(task_definition)

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    comment_data = { comment: 'Responding!', reply_to_id: -1 }

    post_json "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 404, last_response.status
  end

  def test_student_reply_to_student_in_same_unit
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit, with_students: true, student_count: 2)
    project_1 = FactoryBot.create(:project, unit: unit, campus: campus)
    project_2 = FactoryBot.create(:project, unit: unit, campus: campus)
    student_1 = project_1.student
    student_2 = project_2.student

    task_definition = unit.task_definitions.first

    # Add auth_token and username to header
    add_auth_header_for(user: student_1)

    post_json "/api/projects/#{project_1.id}/task_def_id/#{task_definition.id}/comments", comment: 'Hello World'
    assert_equal 201, last_response.status
    id = last_response_body['id']

    # Add auth_token and username to header
    add_auth_header_for(user: student_2)

    post_json "/api/projects/#{project_1.id}/task_def_id/#{task_definition.id}/comments", comment: 'Hello World', reply_to_id: id
    assert_equal 403, last_response.status
  end

  def test_student_reply_to_themselve_in_different_task_same_project
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create(:unit, with_students: true, student_count: 2)
    project_1 = FactoryBot.create(:project, unit: unit, campus: campus)
    student_1 = project_1.student

    task_definition_1 = unit.task_definitions.first
    task_definition_2 = unit.task_definitions.second

    # Add auth_token and username to header
    add_auth_header_for(user: student_1)

    post_json "/api/projects/#{project_1.id}/task_def_id/#{task_definition_1.id}/comments", comment: 'Hello World'
    assert_equal 201, last_response.status
    id = last_response_body['id']

    # Add auth_token and username to header
    add_auth_header_for(user: student_1)

    post_json "/api/projects/#{project_1.id}/task_def_id/#{task_definition_2.id}/comments", comment: 'Hello World', reply_to_id: id
    assert_equal 404, last_response.status
  end

  def test_student_reply_to_other_student_in_same_group
    unit = FactoryBot.create :unit, with_students: true

    group_set = GroupSet.create!(name: 'test_student_reply_to_other_student_in_same_group', unit: unit)
    group_set.save!

    group = Group.create!(group_set: group_set, name: 'test_student_reply_to_other_student_in_same_group', tutorial: unit.tutorials.first)

    group.add_member(unit.active_projects[0])
    group.add_member(unit.active_projects[1])
    group.add_member(unit.active_projects[2])
    group.save!

    project = group.projects.first

    # td = FactoryBot.create(:task_definition, unit: unit, group_set: group_set)
    td = TaskDefinition.new(unit_id: unit.id,
                            tutorial_stream: unit.tutorial_streams.first,
                            name: 'Task to switch from ind to group after submission',
                            description: 'test def',
                            weighting: 4,
                            target_grade: 0,
                            start_date: Time.zone.now - 1.week,
                            target_date: Time.zone.now - 1.day,
                            due_date: Time.zone.now + 1.week,
                            abbreviation: 'TaskSwitchIndGrp',
                            restrict_status_updates: false,
                            upload_requirements: [ { 'key' => 'file0', 'name' => 'Shape Class', 'type' => 'code' } ],
                            plagiarism_warn_pct: 0.8,
                            is_graded: false,
                            max_quality_pts: 0,
                            group_set: group_set)
    td.save!

    # Add auth_token and username to header
    add_auth_header_for(user: group.projects.first.student)

    # Student 1 in group post first comment
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment: 'Hello World'
    assert_equal 'Hello World', last_response_body['comment']

    assert_equal 201, last_response.status
    id = last_response_body['id']

    # Add auth_token and username to header
    project = group.projects.second
    add_auth_header_for(user: project.student)

    # Student 2 in group replies
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment: 'Hello World 2', reply_to_id: id
    assert_equal 'Hello World 2', last_response_body['comment'], last_response_body.inspect
    assert_equal 201, last_response.status
  end

  def test_student_reply_to_other_student_in_different_group
    campus = FactoryBot.create(:campus)
    unit = FactoryBot.create :unit, with_students: true
    # project_1 = FactoryBot.create(:project, unit: unit, campus: campus)

    group_set = GroupSet.create!(name: 'test_student_reply_to_other_student_in_same_group', unit: unit)
    group_set.save!

    group_1 = Group.create!(group_set: group_set, name: 'test_1', tutorial: unit.tutorials.first)

    group_1.add_member(unit.active_projects[0])
    group_1.save!

    group_2 = Group.create!(group_set: group_set, name: 'test_2', tutorial: unit.tutorials.first)

    group_2.add_member(unit.active_projects[1])
    group_2.save!

    project = group_1.projects.first

    td = FactoryBot.create(:task_definition, unit: unit, group_set: group_set)

    # Add auth_token and username to header
    add_auth_header_for(user: unit.active_projects[0].student)

    # Student 1 in group post first comment
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment: 'Hello World'
    # assert_equal last_response, "test"
    assert_equal 201, last_response.status
    id = last_response_body['id']

    # Add auth_token and username to header
    add_auth_header_for(user: unit.active_projects[1].student)

    # Student 2 in group 2 replies
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/comments", comment: 'Hello World 2', reply_to_id: id
    # assert_equal last_response, "test"
    assert_equal 403, last_response.status
  end

  def test_convenor_reply_in_wrong_unit
    campus = FactoryBot.create(:campus)
    unit_1 = FactoryBot.create(:unit, with_students: true, student_count: 2)
    unit_1.employ_staff(User.first, Role.convenor)
    project_1 = FactoryBot.create(:project, unit: unit_1, campus: campus)
    student_1 = project_1.student
    task_definition_1 = unit_1.task_definitions.first

    # Add auth_token and username to header
    add_auth_header_for(user: student_1)

    # Student makes a comment on task 1 in unit 1
    post_json "/api/projects/#{project_1.id}/task_def_id/#{task_definition_1.id}/comments", comment: 'Hello World'
    assert_equal 201, last_response.status
    id = last_response_body['id']

    unit_2 = FactoryBot.create(:unit, with_students: true, student_count: 2)
    project_2 = FactoryBot.create(:project, unit: unit_2, campus: campus)
    task_definition_2 = unit_2.task_definitions.first
    unit_2.employ_staff(User.first, Role.convenor)

    # Add auth_token and username to header
    add_auth_header_for(user: User.first)

    # Convenor replies to that comment in a different unit/projet
    post_json "/api/projects/#{project_2.id}/task_def_id/#{task_definition_2.id}/comments", comment: 'Hello World', reply_to_id: id
    assert_equal 404, last_response.status
  end

  def test_student_post_image_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    comment_data = { attachment: upload_file('test_files/submissions/Deakin_Logo.jpeg', 'image/jpeg') }

    post "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, 'one comment added'

    new_comment = TaskComment.last

    assert_equal 'image comment', new_comment.comment, 'last comment has message'
    assert File.exist?(new_comment.attachment_path)

    new_comment.destroy
  end

  def test_student_post_gif_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    comment_data = { attachment: upload_file('test_files/submissions/unbelievable.gif', 'image/gif') }

    post "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, 'one comment added'

    new_comment = TaskComment.last

    assert_equal 'image comment', new_comment.comment, 'last comment has message'
    assert File.exist?(new_comment.attachment_path)
    assert_equal '.gif', new_comment.attachment_extension, 'attachment is a gif'

    new_comment.destroy
  end

  def test_student_post_pdf_comment
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    comment_data = { attachment: upload_file('test_files/submissions/00_question.pdf', 'application/pdf') }

    post "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, 'one comment added'

    new_comment = TaskComment.last

    assert_equal 'pdf document', new_comment.comment, 'last comment has message'
    assert File.exist?(new_comment.attachment_path)
    assert_equal '.pdf', new_comment.attachment_extension, 'attachment is a pdf'

    new_comment.destroy
  end

  def test_comment_attachments_deleted
    project = Project.first
    user = project.student
    unit = project.unit
    task_definition = unit.task_definitions.first

    pre_count = TaskComment.count

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    comment_data = { attachment: upload_file('test_files/submissions/00_question.pdf', 'application/pdf') }

    post "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 201, last_response.status

    assert_equal pre_count + 1, TaskComment.count, 'one comment added'

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

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    comment_data = { attachment: upload_file('test_files/submissions/boo.png', 'image/png') }

    post "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/comments", comment_data

    assert_equal 500, last_response.status

    assert_equal pre_count, TaskComment.count, 'No comment should be created'
    assert_equal 'Attachment is empty.', last_response_body['error']
  end

  def test_read_receipts_for_task_status_comments
    project = Project.first
    user = project.student
    unit = project.unit

    td = TaskDefinition.new(unit_id: unit.id,
                            tutorial_stream: unit.tutorial_streams.first,
                            name: 'test_read_receipts_for_task_status_comments',
                            description: 'test_read_receipts_for_task_status_comments',
                            weighting: 4,
                            target_grade: 0,
                            start_date: Time.zone.now - 2.weeks,
                            target_date: Time.zone.now + 1.week,
                            due_date: Time.zone.now + 2.weeks,
                            abbreviation: 'test_read_receipts_for_task_status_comments',
                            restrict_status_updates: false,
                            upload_requirements: [ ],
                            plagiarism_warn_pct: 0.8,
                            is_graded: false,
                            max_quality_pts: 0)
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Make a submission for this student
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.ready_for_feedback, task.task_status

    refute task.comments.last.new_for?(user)
    refute task.comments.last.new_for?(project.tutor_for(td))

    td.destroy!
  end
end
