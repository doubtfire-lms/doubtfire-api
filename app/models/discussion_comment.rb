# frozen_string_literal: true
class DiscussionComment < ActiveRecord::Base
  include FileHelper

  belongs_to :task_comment
  validates :task_comment, presence: true

  def attachment_path(_count)
    FileHelper.comment_prompt_path(self.task_comment, ".wav", _count)
  end

  def add_prompt(file_upload, _count)
    temp = Tempfile.new(['comment', '.wav'])
    return false unless process_audio(file_upload.tempfile.path, temp.path)
    save
    logger.info("Saving audio prompt to #{attachment_path(_count)}")
    FileUtils.mv temp.path, attachment_path(_count)
  end
end
