class Role < ApplicationRecord
  #
  # Override find to ensure that role objects are cached - these do not change
  #
  def self.find(id)
    Rails.cache.fetch("roles/#{id}", expires_in: 12.hours) do
      super
    end
  end

  def self.admin_staff_ids
    [self.convenor_id, self.admin_id, self.auditor_id]
  end

  def self.teaching_staff_ids
    [self.tutor_id, self.convenor_id, self.admin_id, self.auditor_id]
  end

  def self.student
    Role.find(student_id)
  end

  def self.tutor
    Role.find(tutor_id)
  end

  def self.convenor
    Role.find(convenor_id)
  end

  def self.admin
    Role.find(admin_id)
  end

  def self.auditor
    Role.find(auditor_id)
  end

  def to_sym
    name.downcase.to_sym
  end

  #
  # Checks to see if the role returned by aaf is tutor, returns student if
  # it is anything else.
  #
  if AuthenticationHelpers.aaf_auth?
    def self.aaf_affiliation_to_role_id(affiliation)
      affiliation.include?('staff') ? Role.tutor.id : Role.student.id
    end
  end

  #
  # Helpers to get the role id's:
  # - These could be made into DB queries, but these values should not change
  #
  def self.student_id
    1
  end

  def self.tutor_id
    2
  end

  def self.convenor_id
    3
  end

  def self.admin_id
    4
  end

  def self.auditor_id
    5
  end

  def self.with_name(name)
    case name
    when /[Aa]dmin/
      admin
    when /[Aa]uditor/
      auditor
    when /[Cc]onvenor/
      convenor
    when /[Tt]utor/
      tutor
    when /[Ss]tudent/
      student
    end
  end
end
