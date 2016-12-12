class Role < ActiveRecord::Base
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

  def to_sym
    name.downcase.to_sym
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

  def self.with_name(name)
    case name
    when /[Aa]dmin/
      admin
    when /[Cc]onvenor/
      convenor
    when /[Tt]utor/
      tutor
    when /[Ss]tudent/
      student
    end
  end
end
