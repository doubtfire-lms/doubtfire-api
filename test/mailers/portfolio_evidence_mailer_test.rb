require 'test_helper'

class PortfolioEvidenceMailerTest < ActionMailer::TestCase

  #
  # Init params for send mail function
  #
  setup do
    @unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])
    @project = @unit.students.first
    task_definition = @unit.task_definitions.first
    @tasks = []
    @tasks << @project.task_for_task_definition(task_definition)
  end

  #
  # Send an email from main tutor to student in a project when having submitted tasks fail
  #
  test 'task_pdf_failed' do
    email = PortfolioEvidenceMailer.task_pdf_failed(@project, @tasks)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@project.main_tutor.email], email.from
    assert_equal [@project.student.email], email.to
    assert_equal "#{@project.unit.name}: Task PDFs ready to view", email.subject
    assert_equal '', email.body.to_s
  end

  #
  # function task_pdf_failed do not send email if the list task is empty
  #
  test 'task_pdf_failed do not send email' do
    email = PortfolioEvidenceMailer.task_pdf_failed(@project, [])
    assert_emails 0 do
      email.deliver_now
    end
  end

  #
  # Send an email from main tutor to student in project when having submitted tasks ready to be viewed and assessed
  #
  test 'task_pdf_ready_message' do
    email = PortfolioEvidenceMailer.task_pdf_ready_message(@project, @tasks)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@project.main_tutor.email], email.from
    assert_equal [@project.student.email], email.to
    assert_equal "#{@project.unit.name}: Task PDFs ready to view", email.subject
    assert_equal '', email.body.to_s
  end

  #
  # Send an email from main tutor to student in project when having submitted tasks to be feedback
  #
  test 'task_feedback_ready' do
    email = PortfolioEvidenceMailer.task_feedback_ready(@project, @tasks)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@project.main_tutor.email], email.from
    assert_equal [@project.student.email], email.to
    assert_equal "#{@project.unit.name}: Feedback ready to review", email.subject
    assert_equal '', email.body.to_s
  end

  #
  # Send an email from first convenor to student in project when having portfolio ready to review
  #
  test 'portfolio_ready' do
    email = PortfolioEvidenceMailer.portfolio_ready(@project)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@project.unit.convenors.first.user.email], email.from
    assert_equal [@project.student.email], email.to
    assert_equal "#{@project.unit.name}: Portfolio ready to review", email.subject
    assert_equal '', email.body.to_s
  end

  #
  # function portfolio_ready do not send email if project is nil 
  #
  test 'portfolio_ready do not send email' do
    email = PortfolioEvidenceMailer.portfolio_ready(nil)
    assert_emails 0 do
      email.deliver_now
    end
  end

  #
  # Send an email from first convenor to student in project when having portfolio failed to compile
  #
  test 'portfolio_failed' do
    email = PortfolioEvidenceMailer.portfolio_failed(@project)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@project.unit.convenors.first.user.email], email.from
    assert_equal [@project.student.email], email.to
    assert_equal "#{@project.unit.name}: Portfolio failed to compile", email.subject
    assert_equal '', email.body.to_s
  end
end