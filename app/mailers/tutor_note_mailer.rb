class TutorNoteMailer < ApplicationMailer
  def add_general
    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/edit_profile"
  end

  def notify_tutor_note(tutor_note, recipient)
    add_general

    @note = tutor_note
    @recipient = recipient

    @from = tutor_note.user

    @unit = tutor_note.unit_role.unit
    @mentor = @unit.unit_role_for(@from)

    @task = tutor_note.task

    recipient_email_with_name = %("#{recipient.name}" <#{recipient.email}>)
    tutor_email = %("#{@from.name}" <#{@from.email}>)
    subject = "#{@unit.name}: New tutor note from #{@from.name}"
    mail(to: recipient_email_with_name, from: tutor_email, subject: subject)
  end

end
