class NotifyTutorNotesJob
  include Sidekiq::Job

  def perform(tutor_note_id, recipient_user_id)
    tutor_note = TutorNote.find(tutor_note_id)
    recipient = User.find(recipient_user_id)

    TutorNoteMailer.notify_tutor_note(tutor_note, recipient).deliver
  rescue StandardError => e
    Rails.logger.error("Failed to send tutor note email for TutorNote #{tutor_note_id} to User #{recipient_user_id}: #{e.class} - #{e.message}")
  end
end
