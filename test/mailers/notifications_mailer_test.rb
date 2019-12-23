require 'test_helper'

class NotificationsMailerTest < ActionMailer::TestCase

  #
  # Init params for send mail function
  #
  setup do
    @unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])
    @unit_role = @unit.unit_roles.first
    @convenor = @unit.main_convenor
    @summary_stats = {
      unit: @unit,
      staff: {},
      revert: {},
      convenor: @convenor,
      week_start: '20190908'.to_date,
      week_end: '20190908'.to_date - 7.days,
      num_students_without_tutors: 8,
      revert_count: 2,
      unit_week_comments: 1
    }
    @summary_stats[:staff][@unit_role] = {
      received_comments: 10,
      sent_comments: 5,
      total_comments: 15,
      tasks_awaiting_feedback_count: 4,
      oldest_task_days: 2,
      number_of_students: 3,
      staff: @unit_role.user,
      total_staff_engagements: 3,
      staff_engagements: 6,
    }
    @summary_stats[:revert][@unit_role.user] = []
  end

  #
  # Send an email from convenor to staff in a unit role to summary of week with number students without tutor > 1
  #
  test 'weekly_staff_summary use helper are_is return are' do
    email = NotificationsMailer.weekly_staff_summary(@unit_role, @summary_stats)

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@convenor.email], email.from
    assert_equal [@unit_role.user.email], email.to
    assert_equal "#{@unit.name}: Weekly Summary", email.subject
    assert_equal '', email.body.to_s
  end

  #
  # Send an email from convenor to staff in a unit role to summary of week with number students without tutor equal 1
  #
  test 'weekly_staff_summary use helper are_is return is' do
    @summary_stats[:num_students_without_tutors] = 1
    email = NotificationsMailer.weekly_staff_summary(@unit_role, @summary_stats)

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@convenor.email], email.from
    assert_equal [@unit_role.user.email], email.to
    assert_equal "#{@unit.name}: Weekly Summary", email.subject
    assert_equal '', email.body.to_s
  end

  #
  # Send an email from main tutor to student in a project to summary of week
  #
  test 'weekly_student_summary' do
    project = @unit.students.first
    task_definition = @unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)
    unit = project.unit
    unit_role = UnitRole.find_by_unit_id(unit.id)
    did_revert_to_pass = true

    email = NotificationsMailer.weekly_student_summary(project, @summary_stats, did_revert_to_pass)

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [project.main_tutor.email], email.from
    assert_equal [project.student.email], email.to
    assert_equal "#{unit.name}: Weekly Summary", email.subject
    assert_equal '', email.body.to_s
  end
end