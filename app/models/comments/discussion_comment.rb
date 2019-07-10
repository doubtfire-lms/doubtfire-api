class DiscussionComment < TaskComment
  include FileHelper

  def status
    return "not started" if not started and not completed
    return "opened" if started and not completed
    return "complete"
  end

  def attachment_path(_count = number_of_prompts)
    FileHelper.comment_prompt_path(self, ".wav", _count)
  end

  def attachment_file_name(number)
    "discussion-#{id}-#{number}-#{attachment_extension}"
  end

  def reply_attachment_path
    FileHelper.comment_reply_prompt_path(self, ".wav")
  end

  def serialize(user)
    json = super(user)
    json[:status] = status
    json[:time_discussion_completed] = time_discussion_completed
    json[:time_discussion_started] = time_discussion_started
    json[:number_of_prompts] = number_of_prompts
    json
  end

  def dueDate
    created_at + 10.days
  end

  def started
    not self.time_discussion_started.nil?
  end

  def completed
    not self.time_discussion_completed.nil?
  end

  def mark_discussion_started
    self.time_discussion_started = Time.zone.now
    self.save!
  end

  def mark_discussion_completed
    self.time_discussion_completed = Time.zone.now
    self.save!
  end

  def add_prompt(file_upload, _count)
    temp = Tempfile.new(['discussion_comment', '.wav'])
    return false unless process_audio(file_upload.tempfile.path, temp.path)
    save
    logger.info("Saving audio prompt to #{attachment_path(_count)}")
    FileUtils.mv temp.path, attachment_path(_count)

    file_upload.tempfile.unlink
    true
  end

  def add_reply(reply_attachment)
    temp = Tempfile.new(['discussion_comment_reply', '.wav'])
    return false unless process_audio(reply_attachment.tempfile.path, temp.path)
    mark_discussion_completed
    save
    logger.info("Saving discussion comment reply to #{reply_attachment_path()}")
    FileUtils.mv temp.path, reply_attachment_path

    reply_attachment.tempfile.unlink
    true
  end
end
