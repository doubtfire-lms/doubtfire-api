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
  alias :super_mark_as_read :mark_as_read

  # Allow individual staff and the student to read this... but stop
  # the main tutor reading without assessing. As only the main tutor
  # propagates reads, this will work as required - other staff cant
  # make it read for the main tutor.
  def mark_as_read(user, unit = self.unit)
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
