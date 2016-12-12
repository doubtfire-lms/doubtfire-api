# getting file MIME types
require 'filemagic'

module MimeCheckHelpers
  def mime_type(file_path)
    fm = FileMagic.new(FileMagic::MAGIC_MIME)
    fm.file(file_path)
  end

  def ensure_csv!(file_path)
    file_path = file_path.path if file_path.is_a?(Tempfile)
    type = mime_type(file_path)

    # check mime is correct before uploading
    accept = ['text/', 'text/plain', 'text/csv']
    unless type.start_with?(*accept)
      error!({ error: "File given is not a csv file - detected #{type}" }, 403)
    end
  end

  def mime_in_list?(file, type_list)
    type = mime_type(file)

    # check mime is correct before uploading
    type.start_with?(*type_list)
  end

  def check_mime_against_list!(file, expect, type_list)
    unless mime_in_list?(file, type_list)
      error!({ error: "File given is not a #{expect} file - detected #{mime_type}" }, 403)
    end
  end

  module_function :ensure_csv!
  module_function :check_mime_against_list!
  module_function :mime_in_list?
  module_function :mime_type
end
