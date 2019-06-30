# frozen_string_literal: true
class DiscussionComment < ActiveRecord::Base
  include FileHelper

  belongs_to :task_comment
  validates :task_comment, presence: true

  def status
    return "not started" if started and completed
    return "opened" if started and not completed
    return "complete"
  end

  def attachment_path(_count)
    FileHelper.comment_prompt_path(self.task_comment, ".wav", _count)
  end

  def startDiscussion()
    self.time_started = DateTime.now
    self.save!
  end

  def dueDate
    created_at + 10.days
  end

  def started
    not time_started.nil?
  end

  def completed
    not time_completed.nil?
  end

  def add_prompt(file_upload, _count)
    temp = Tempfile.new(['discussion_comment', '.wav'])
    return false unless process_audio(file_upload.tempfile.path, temp.path)
    save
    logger.info("Saving audio prompt to #{attachment_path(_count)}")
    FileUtils.mv temp.path, attachment_path(_count)
  end
end
