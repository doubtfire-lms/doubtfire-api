#
# The status
# - has a name and a description
class TaskStatus < ApplicationRecord
  # TODO: Consider refactoring this class. Is there any point to having this in the database? Could this become an enum?

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

  def self.not_started
    TaskStatus.find(1)
  end

  def self.complete
    TaskStatus.find(2)
  end

  def self.need_help
    TaskStatus.find(3)
  end

  def self.working_on_it
    TaskStatus.find(4)
  end

  def self.fix_and_resubmit
    TaskStatus.find(5)
  end

  def self.feedback_exceeded
    TaskStatus.find(6)
  end

  def self.redo
    TaskStatus.find(7)
  end

  def self.discuss
    TaskStatus.find(8)
  end

  def self.ready_for_feedback
    TaskStatus.find(9)
  end

  def self.demonstrate
    TaskStatus.find(10)
  end

  def self.fail
    TaskStatus.find(11)
  end

  def self.time_exceeded
    TaskStatus.find(12)
  end

  class << self
    # Provide access to the count from the database via a new db_count method
    alias_method :db_count, :count
  end

  # Return the count (which equals the largest id) - so that other code can loop thought all statuses without database lookup
  #
  # Make sure to update this if/when you add another status!
  #
  # Keep this hard coded! Saves cache load time.
  # Important: count must equal the largest id in the database
  def self.count
    12
  end

  def self.status_for_name(name)
    case name.downcase.strip
    when 'complete'         then TaskStatus.complete
    when 'fix_and_resubmit' then TaskStatus.fix_and_resubmit
    when 'fix and resubmit' then TaskStatus.fix_and_resubmit
    when 'fix'              then TaskStatus.fix_and_resubmit
    when 'f'                then TaskStatus.fix
    when 'do_not_resubmit'  then TaskStatus.feedback_exceeded
    when 'do not resubmit'  then TaskStatus.feedback_exceeded
    when 'feedback_exceeded'  then TaskStatus.feedback_exceeded
    when 'feedback exceeded'  then TaskStatus.feedback_exceeded
    when 'redo'             then TaskStatus.redo
    when 'need_help'        then TaskStatus.need_help
    when 'need help'        then TaskStatus.need_help
    when 'working_on_it'    then TaskStatus.working_on_it
    when 'working on it'    then TaskStatus.working_on_it
    when 'discuss', 'd'     then TaskStatus.discuss
    when 'demonstrate'      then TaskStatus.demonstrate
    when 'demo'             then TaskStatus.demonstrate
    when 'ready for feedback'    then TaskStatus.ready_for_feedback
    when 'ready_for_feedback'    then TaskStatus.ready_for_feedback
    when 'ready to mark'    then TaskStatus.ready_for_feedback
    when 'ready_to_mark'    then TaskStatus.ready_for_feedback
    when 'rtm'              then TaskStatus.ready_for_feedback
    when 'rff'              then TaskStatus.ready_for_feedback
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

  def self.id_to_key(id)
    case id
    when 1 then :not_started
    when 2 then :complete
    when 3 then :need_help
    when 4 then :working_on_it
    when 5 then :fix_and_resubmit
    when 6 then :feedback_exceeded
    when 7 then :redo
    when 8 then :discuss
    when 9 then :ready_for_feedback
    when 10 then :demonstrate
    when 11 then :fail
    when 12 then :time_exceeded
    else :not_started
    end
  end

  def status_key
    return :complete if self == TaskStatus.complete
    return :not_started if self == TaskStatus.not_started
    return :fix_and_resubmit if self == TaskStatus.fix_and_resubmit
    return :redo if self == TaskStatus.redo
    return :need_help if self == TaskStatus.need_help
    return :working_on_it if self == TaskStatus.working_on_it
    return :discuss if self == TaskStatus.discuss
    return :ready_for_feedback if self == TaskStatus.ready_for_feedback
    return :demonstrate if self == TaskStatus.demonstrate
    return :fail if self == TaskStatus.fail
    return :feedback_exceeded if self == TaskStatus.feedback_exceeded
    return :time_exceeded if self == TaskStatus.time_exceeded

    return :not_started
  end
end
