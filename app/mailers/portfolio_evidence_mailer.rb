class PortfolioEvidenceMailer < ActionMailer::Base

  def task_pdf_ready_message (project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.length == 0

    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_tutor
    @convenor = project.main_convenor
    @unsubscribe_url = "#{Doubtfire::Application.config.mail_base_url}home?notifications"

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{project.unit.name}: Task PDFs ready to view"

    mail(
      to:       email_with_name,
      from:     convenor_email,
      subject:  subject)
  end

  def task_feedback_ready (project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.length == 0

    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_tutor
    @hasComments = @tasks.select { |t| not t.last_comment_by(@tutor).nil? }.length > 0
    return nil if @tutor.nil? || @student.nil?

    #@tasks = @tasks.sort_by { |t| t.due_date }
    @unsubscribe_url = "#{Doubtfire::Application.config.mail_base_url}home?notifications"

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Feedback ready to review"

    mail(
      to:       email_with_name,
      from:     tutor_email,
      subject:  subject)
  end

  def portfolio_ready (project)
    return nil if project.nil?

    @student = project.student
    @project = project
    @unsubscribe_url = "#{Doubtfire::Application.config.mail_base_url}home?notifications"
    @convenor = project.unit.convenors.first.user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{project.unit.name}: Portfolio ready to review"

    mail(
      to:       email_with_name,
      from:     convenor_email,
      subject:  subject)
  end


end
