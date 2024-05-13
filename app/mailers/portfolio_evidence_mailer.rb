class PortfolioEvidenceMailer < ActionMailer::Base
  def add_general
    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/#/home?notifications"
  end

  def task_pdf_failed(project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.empty?

    add_general
    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_convenor_user
    @convenor = project.main_convenor_user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Task PDFs ready to view"
    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def task_pdf_ready_message(project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.empty?

    add_general
    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_convenor_user
    @convenor = project.main_convenor_user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Task PDFs ready to view"
    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def task_feedback_ready(project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.empty?

    add_general
    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_convenor_user
    @has_comments = !@tasks.select { |t| t.is_last_comment_by?(@tutor) }.empty?
    return nil if @tutor.nil? || @student.nil?

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Feedback ready to review"
    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def portfolio_ready(project)
    return nil if project.nil?

    add_general

    @student = project.student
    @project = project
    @convenor = project.main_convenor_user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{project.unit.name}: Portfolio ready to review"
    mail(to: email_with_name, from: convenor_email, subject: subject)
  end

  def portfolio_failed(project)
    return nil if project.nil?

    add_general

    @student = project.student
    @project = project
    @convenor = project.main_convenor_user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{project.unit.name}: Portfolio failed to compile"
    mail(to: email_with_name, from: convenor_email, subject: subject)
  end
end
