#
# The status
# - has a name and a description
class TaskStatus < ActiveRecord::Base
  # Model associations
  has_many :tasks

  scope :not_started,     -> { TaskStatus.find(1) }
  scope :complete,          -> { TaskStatus.find(2) }
  scope :need_help,         -> { TaskStatus.find(3) }
  scope :working_on_it,     -> { TaskStatus.find(4) }
  scope :fix_and_resubmit,  -> { TaskStatus.find(5) }
  scope :do_not_resubmit,   -> { TaskStatus.find(6) }
  scope :redo,              -> { TaskStatus.find(7) }
  scope :discuss,           -> { TaskStatus.find(8) }
  scope :ready_to_mark,     -> { TaskStatus.find(9) }
  scope :demonstrate,       -> { TaskStatus.find(10) }
  scope :fail,              -> { TaskStatus.find(11) }

  def self.status_for_name(name)
    case name.downcase.strip
      when "complete"         then TaskStatus.complete
      when "fix_and_resubmit" then TaskStatus.fix_and_resubmit
      when "fix and resubmit" then TaskStatus.fix_and_resubmit
      when "do_not_resubmit"  then TaskStatus.do_not_resubmit
      when "fix and include"  then TaskStatus.do_not_resubmit
      when "redo"             then TaskStatus.redo
      when "need_help"        then TaskStatus.need_help
      when "need help"        then TaskStatus.need_help
      when "working_on_it"    then TaskStatus.working_on_it
      when "working on it"    then TaskStatus.working_on_it
      when "discuss"          then TaskStatus.discuss
      when "ready to mark"    then TaskStatus.ready_to_mark
      when "ready_to_mark"    then TaskStatus.ready_to_mark
      when "fail"             then TaskStatus.fail
      when "f"                then TaskStatus.fail
      else                    TaskStatus.not_started
    end
  end

  def self.staff_assigned_statuses
    TaskStatus.where("id > 4")
  end

  def self.status_key_for_name(name)
    case name
      when "Complete"         then :complete
      when "Not Started"      then :not_started
      when "Fix and Resubmit" then :fix_and_resubmit
      when "Fix and Include"  then :do_not_resubmit
      when "Redo"             then :redo
      when "Need Help"        then :need_help
      when "Working On It"    then :working_on_it
      when "Discuss"          then :discuss
      when "Ready to Mark"    then :ready_to_mark
      when "Demonstrate"      then :demonstrate
      when "Fail"             then :fail
      else :not_started
    end
  end

  def status_key
    TaskStatus.status_key_for_name(name)
  end

end