# freeze_string_literal: true

# Turn It In Submission objects track individual files submitted to turn it in for
# processing. This will track objects through the process, from submission until
# we receive the similarity report.
class TiiSubmission < ApplicationRecord
  belongs_to :submitted_by_user, class_name: 'User'
  belongs_to :task
  has_many :tii_actions, as: :entity, dependent: :destroy

  before_destroy :delete_submission

  # The user who submitted the file. From this we determine who will
  # submit this to turn it in. It will be the user, their tutor, or
  # the main convenor of the project.
  #
  # @param user [User] the user who is submitting the task
  def submitted_by=(user)
    if user.has_accepted_tii_eula?
      self.submitted_by_user = user
    elsif task.tutor.has_accepted_tii_eula?
      self.submitted_by_user = task.tutor
    elsif task.project.main_convenor_user.has_accepted_tii_eula?
      self.submitted_by_user = task.project.main_convenor_user
    else
      self.submitted_by_user = user
      self.error_code = :no_user_with_accepted_eula
    end
    save
  end

  # The user who submitted the file to turn it in.
  def submitted_by
    submitted_by_user
  end

  enum status: {
    created: 0,
    has_id: 1,
    uploaded: 2,
    submission_complete: 3,
    similarity_report_requested: 4,
    similarity_report_complete: 5,
    similarity_pdf_requested: 6,
    similarity_pdf_available: 7,
    similarity_pdf_downloaded: 8,
    to_delete: 9,
    deleted: 10,
    complete_low_similarity: 11
  }

  def status_sym
    status.to_sym
  end

  def similarity_pdf_path
    path = FileHelper.student_work_dir(:plagarism, task)
    File.join(path, FileHelper.sanitized_filename("#{id}-tii.pdf"))
  end

  # Delete the turn it in submission for a task
  #
  # @return [Boolean] true if the submission was deleted, false otherwise
  def delete_submission
    self.status = :to_delete
    save

    TurnItIn.exec_tca_call "TiiSubmission #{id} - deleting submission" do
      TCAClient::SubmissionApi.new.delete_submission(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id
      )

      Doubtfire::Application.config.logger.info "Deleted tii submission #{id} for task #{task.id}"

      self.status = :deleted
      save_and_reset_retry
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, message: 'Submission not found in delete submission' },
      { code: 409, message: 'Submission is in an error state' }
    ]
    false
  end
end
