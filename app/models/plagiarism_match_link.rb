class PlagiarismMatchLink < ActiveRecord::Base
  belongs_to :task
  belongs_to :other_task, :class_name => 'Task'

  #
  # Ensure file is also deleted
  #
  before_destroy do | match_link |
    begin
      FileHelper.delete_plagarism_html(match_link)
    rescue
    end
  end

  #
  # Update task's cache of pct similar
  #
  after_save do | match_link |
    task = match_link.task
    if task.max_pct_similar < match_link.pct 
      task.max_pct_similar = match_link.pct 
      task.save
    end
  end
end