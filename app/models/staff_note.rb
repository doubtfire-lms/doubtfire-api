class StaffNote < ApplicationRecord
  include MimeCheckHelpers

  ATTACHMENT_EXTENSIONS = {
    'image/jpeg' => '.jpg',
    'image/gif' => '.gif',
    'application/pdf' => '.pdf'
  }.freeze

  belongs_to :project
  belongs_to :user

  validates :content_type, inclusion: { in: ATTACHMENT_EXTENSIONS.keys, allow_nil: true }

  after_destroy :delete_attachment

  def attachment_extension
    ATTACHMENT_EXTENSIONS[content_type]
  end

  def attachment?
    content_type.present? && File.file?(attachment_path)
  end

  def attachment_type
    return nil if content_type.nil?

    content_type == 'application/pdf' ? 'pdf' : 'image'
  end

  def attachment_path
    attachment_path_for(attachment_extension) unless content_type.nil?
  end

  def attachment_file_name
    "staff-note-#{id}#{attachment_extension}"
  end

  def add_attachment(file_upload, type)
    self.content_type = if type == 'pdf'
                          'application/pdf'
                        elsif mime_type(file_upload['tempfile'].path).start_with?('image/gif')
                          'image/gif'
                        else
                          'image/jpeg'
                        end
    save!

    path = attachment_path
    FileUtils.mkdir_p(File.dirname(path))

    if type == 'pdf'
      FileHelper.compress_pdf(file_upload['tempfile'].path)
      FileUtils.mv(file_upload['tempfile'].path, path)
    else
      saved = FileHelper.compress_image_to_dest(file_upload['tempfile'].path, path)
      raise 'Failed to save staff note image attachment' unless saved && File.file?(path)
    end
  end

  def delete_attachment
    FileUtils.rm_f(attachment_path) if content_type.present?
  end

  private

  def attachment_path_for(extension)
    File.join(FileHelper.project_work_root(project), 'staff_note', "#{id}#{extension}")
  end

  # belongs_to :reply_to, class_name: 'StaffNote', optional: true, inverse_of: :replies
  # has_many :replies, class_name: 'StaffNote', dependent: :restrict_with_exception, inverse_of: :reply_to
end
