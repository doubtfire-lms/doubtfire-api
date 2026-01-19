require 'test_helper'

class NotificationsMailerTest < ActionMailer::TestCase
  include TestHelpers::AuthHelper

  def setup
    # Mock Doubtfire configuration
    Doubtfire::Application.config.institution = {
      host: 'doubtfire.deakin.edu.au',
      product_name: 'Doubtfire'
    }

    # Create unit and staff
    @unit = FactoryBot.create(:unit)
    @staff = FactoryBot.create(:user, role: Role.tutor)
    @unit.employ_staff(@staff, Role.tutor)

    # Create a task definition
    @task_definition = @unit.task_definitions.create!({
      tutorial_stream: @unit.tutorial_streams.first,
      name: 'Test Task',
      description: 'Test task for notifications',
      weighting: 4,
      target_grade: 0,
      start_date: Time.zone.now - 1.week,
      target_date: Time.zone.now + 1.week,
      due_date: Time.zone.now + 2.weeks,
      abbreviation: 'TESTTASK',
      restrict_status_updates: false,
      upload_requirements: [],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 0
    })

    # Create students and projects with notification preferences
    @students = []
    @projects = []

    # Create one student with notifications enabled
    student_with_notifications = FactoryBot.create(:user, role: Role.student)
    student_with_notifications.update(receive_task_notifications: true)
    project = @unit.projects.create!(user: student_with_notifications, enrolled: true)
    @students << student_with_notifications
    @projects << project

    # Create two students without notifications
    2.times do
      student = FactoryBot.create(:user, role: Role.student)
      student.update(receive_task_notifications: false)
      project = @unit.projects.create!(user: student, enrolled: true)
      @students << student
      @projects << project
    end

    # Clear any existing emails before each test
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    # @task_definition.destroy!
    # @unit.destroy!
    ActionMailer::Base.deliveries.clear
  end

  test 'creates correct extension summary email' do
    # Create extensions
    extensions = []
    @projects.each do |project|
      task = project.task_for_task_definition(@task_definition)
      extension = task.apply_for_extension(@staff, 'Test comment', 1)
      extension.assess_extension(@staff, true, true)
      extensions << extension
    end

    # Get the mail object
    mail = NotificationsMailer.extension_granted_summary(extensions, @staff, extensions.count)

    # Verify email properties
    assert_equal [@staff.email], mail.to
    assert_equal "#{@unit.name}: Staff Grant Extensions", mail.subject
    assert_match /You have granted extensions for the following students/, mail.html_part.body.to_s

    # Verify from address contains no-reply
    assert_includes mail.from.first, "no-reply@"
    assert_includes mail.from.first, NotificationsMailer.doubtfire_host
  end

  test 'creates correct extension notification email' do
    # Create extension
    project = @projects.first
    task = project.task_for_task_definition(@task_definition)
    extension = task.apply_for_extension(@staff, 'Test comment', 1)
    extension.assess_extension(@staff, true, true)

    # Get the mail object
    mail = NotificationsMailer.extension_granted_notification(extension, @staff)

    # Verify email properties
    assert_equal [@students.first.email], mail.to
    assert_equal "#{@unit.name}: Extension granted for #{@task_definition.name}", mail.subject
    assert_match /Dear #{@students.first.first_name}/, mail.html_part.body.to_s

    # Verify from address contains staff email
    assert_includes mail.from.first, @staff.email
  end

  test 'creates correct extension summary with failed extensions' do
    # Create successful extensions
    successful_extensions = []
    @projects.each do |project|
      task = project.task_for_task_definition(@task_definition)
      extension = task.apply_for_extension(@staff, 'Test comment', 1)
      extension.assess_extension(@staff, true, true)
      successful_extensions << extension
    end

    # Create failed extensions
    failed_extensions = [
      { student_id: 999, error: 'Student not found in unit' },
      { student_id: 1000, error: 'Extension cannot be granted beyond task deadline' }
    ]

    # Get the mail object
    mail = NotificationsMailer.extension_granted_summary(
      successful_extensions,
      @staff,
      successful_extensions.count,
      failed_extensions
    )

    # Verify email includes failed extensions
    assert_equal [@staff.email], mail.to
    assert_match /Failed Extensions/, mail.html_part.body.to_s
    assert_match /999/, mail.html_part.body.to_s
    assert_match /1000/, mail.html_part.body.to_s

    # Verify from address contains no-reply
    assert_includes mail.from.first, "no-reply@"
    assert_includes mail.from.first, NotificationsMailer.doubtfire_host
  end

  test 'creates correct extension notification with special characters' do
    # Create task with special characters
    special_task = @unit.task_definitions.create!({
      tutorial_stream: @unit.tutorial_streams.first,
      name: 'Test Task with !@#$%^&*()',
      description: 'Test task with special characters',
      weighting: 4,
      target_grade: 0,
      start_date: Time.zone.now - 1.week,
      target_date: Time.zone.now + 1.week,
      due_date: Time.zone.now + 2.weeks,
      abbreviation: 'SPECIAL',
      restrict_status_updates: false,
      upload_requirements: [],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 0
    })

    # Create extension
    project = @projects.first
    task = project.task_for_task_definition(special_task)
    extension = task.apply_for_extension(@staff, 'Special characters test', 1)
    extension.assess_extension(@staff, true, true)

    # Get the mail object
    mail = NotificationsMailer.extension_granted_notification(extension, @staff)

    # Verify email handles special characters
    assert_equal [@students.first.email], mail.to
    assert_equal "#{@unit.name}: Extension granted for #{special_task.name}", mail.subject
    assert_match /Dear #{@students.first.name}/, mail.html_part.body.to_s

    # Verify from address contains staff email
    assert_includes mail.from.first, @staff.email

    # Clean up
    special_task.destroy!
  end

  test 'creates correct weekly staff summary email' do
    # Create data for summary stats
    summary_stats = {
      unit: @unit,
      week_start: Time.zone.now - 1.week,
      week_end: Time.zone.now,
      staff: {}
    }

    unit_role = @unit.unit_roles.find_by(user: @staff)
    summary_stats[:staff][unit_role.user] = {
      tasks_awaiting_feedback_count: 1,
      weekly_engagements_count: 2,
      staff_engagements: 3,
      oldest_task_days: 4,
      weekly_total_tasks_discussed: 5
    }

    # Get the mail object
    mail = NotificationsMailer.weekly_staff_summary(unit_role, summary_stats)

    # Verify email properties
    assert_equal [@staff.email], mail.to
    assert_equal "#{@unit.name}: Weekly Summary", mail.subject

    # Verify from address contains convenor email
    assert_includes mail.from.first, @unit.main_convenor_user.email
  end

  test 'creates correct weekly student summary email' do
    # Create data for summary stats
    summary_stats = {
      unit: @unit,
      week_start: Time.zone.now - 1.week,
      week_end: Time.zone.now
    }

    project = @projects.first

    # Get the mail object
    mail = NotificationsMailer.weekly_student_summary(project, summary_stats, false)

    # Verify email properties
    assert_equal [@students.first.email], mail.to
    assert_equal "#{@unit.name}: Weekly Summary", mail.subject

    # Verify from address contains tutor email
    assert_includes mail.from.first, project.main_convenor_user.email
  end
end
