#
# The status
# - has a name and a description
class TaskStatus < ActiveRecord::Base
  # Model associations
  has_many :tasks

  #
  # Override find to ensure that task status objects are cached - these do not change
  #
  def self.find(id)
    Rails.cache.fetch("task_statuses/#{id}", expires_in: 12.hours) do
      super
    end
  end

  scope :not_started,       -> { TaskStatus.find(1) }
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
  scope :time_exceeded,     -> { TaskStatus.find(12) }

  def self.status_for_name(name)
    case name.downcase.strip
    when 'complete'         then TaskStatus.complete
    when 'fix_and_resubmit' then TaskStatus.fix_and_resubmit
    when 'fix and resubmit' then TaskStatus.fix_and_resubmit
    when 'fix'              then TaskStatus.fix_and_resubmit
    when 'f'                then TaskStatus.fix
    when 'do_not_resubmit'  then TaskStatus.do_not_resubmit
    when 'do not resubmit'  then TaskStatus.do_not_resubmit
    when 'redo'             then TaskStatus.redo
    when 'need_help'        then TaskStatus.need_help
    when 'need help'        then TaskStatus.need_help
    when 'working_on_it'    then TaskStatus.working_on_it
    when 'working on it'    then TaskStatus.working_on_it
    when 'discuss', 'd'     then TaskStatus.discuss
    when 'demonstrate'      then TaskStatus.demonstrate
    when 'demo'             then TaskStatus.demonstrate
    when 'ready to mark'    then TaskStatus.ready_to_mark
    when 'ready_to_mark'    then TaskStatus.ready_to_mark
    when 'rtm'              then TaskStatus.ready_to_mark
    when 'fail'             then TaskStatus.fail
    when 'not_started'      then TaskStatus.not_started
    when 'not started'      then TaskStatus.not_started
    when 'ns'               then TaskStatus.not_started
    when 'time exceeded'    then TaskStatus.time_exceeded
    when 'time_exceeded'    then TaskStatus.time_exceeded
    else nil
    end
  end

  def self.staff_assigned_statuses
    TaskStatus.where('id > 4')
  end

  def status_key
    return :complete if self == TaskStatus.complete
    return :not_started if self == TaskStatus.not_started
    return :fix_and_resubmit if self == TaskStatus.fix_and_resubmit
    return :redo if self == TaskStatus.redo
    return :need_help if self == TaskStatus.need_help
    return :working_on_it if self == TaskStatus.working_on_it
    return :discuss if self == TaskStatus.discuss
    return :ready_to_mark if self == TaskStatus.ready_to_mark
    return :demonstrate if self == TaskStatus.demonstrate
    return :fail if self == TaskStatus.fail
    return :do_not_resubmit if self == TaskStatus.do_not_resubmit
    return :time_exceeded if self == TaskStatus.time_exceeded
    return :not_started
  end
end
