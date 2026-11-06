class SubmissionComment < TaskComment
  belongs_to :assessor, class_name: 'User', optional: true

  def serialize(user)
    json = super(user)
    json[:submission_assessed_at] = submission_assessed_at
    json[:submission_granted] = submission_granted
    json
  end

  def assessed?
    submission_assessed_at.present?
  end

  def approved?
    assessed? && submission_granted?
  end

  # Do not let the recipient tutor mark the request as read before assessing it.
  def mark_as_read(user)
    super if assessed? || user == project.student || user != recipient
  end

  def assess_submission_access(user, granted)
    if assessed?
      errors.add(:submission, 'has already been assessed')
      return false
    end

    self.assessor = user
    self.submission_assessed_at = Time.zone.now
    self.submission_granted = granted

    # Now make sure to read it by the main tutor - even if assessed by someone else
    mark_as_read(project.tutor_for(task.task_definition))
    save!
  end
end
