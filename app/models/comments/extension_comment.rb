class ExtensionComment < TaskComment

  belongs_to :assessor, class_name: 'User'

  def serialize(user)
    json = super(user)
    json[:granted] = extension_granted
    json[:assessed] = date_extension_assessed.present?
    json[:date_assessed] = date_extension_assessed
    json[:weeks_requested] = extension_weeks
    json[:extension_response] = extension_response
    json
  end

  def assessed?
    self.date_extension_assessed.present?
  end

  def assess_extension(user, granted)
    if self.assessed?
      self.errors[:extension] << 'has already been assessed'
      return false
    end

    self.assessor = user
    self.date_extension_assessed = Time.zone.now
    self.extension_granted = granted && self.task.can_apply_for_extension?

    if self.extension_granted
      self.task.grant_extension(extension_weeks)
      self.extension_response = "Extension granted to #{self.task.due_date.strftime('%a %b %e')}"
    elsif ! self.task.can_apply_for_extension? && granted
      self.extension_response = "Extension cannot be granted as deadline has been reached"
      errors[:extension] << 'cannot be granted as deadline has been reached'
    else
      self.extension_response = "Extension rejected"
    end

    save!
  end
end
