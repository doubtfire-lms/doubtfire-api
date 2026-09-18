class ScormExtensionComment < TaskComment
  belongs_to :assessor, class_name: 'User', optional: true

  def serialize(user)
    json = super(user)
    json[:granted] = extension_granted
    json[:assessed] = date_extension_assessed.present?
    json[:date_assessed] = date_extension_assessed
    json
  end

  def assessed?
    self.date_extension_assessed.present?
  end

  # Make sure we can access super's version of mark_as_read for assess extension
  alias super_mark_as_read mark_as_read

  # Do not let the recipient tutor mark the request as read before assessing it.
  def mark_as_read(user)
    super if assessed? || user == project.student || user != recipient
  end

  def assess_scorm_extension(user, granted)
    if self.assessed?
      self.errors[:scorm_extension] << 'has already been assessed'
      return false
    end

    self.assessor = user
    self.date_extension_assessed = Time.zone.now
    self.extension_granted = granted

    if self.extension_granted
      self.task.grant_scorm_extension(user)
    end

    # Now make sure to read it by the main tutor - even if assessed by someone else
    super_mark_as_read(project.tutor_for(task.task_definition))
    save!
  end
end
