# getting file MIME types
require 'filemagic'

module MimeCheckHelpers
  extend LogHelper

  def mime_type(file_path)
    fm = FileMagic.new(FileMagic::MAGIC_MIME)
    fm.file(file_path)
  end

  def excel_to_csv(file, extn)
    ss = Roo::Spreadsheet.open(file, extension: extn)

    File.unlink(file)
    File.write(file, ss.sheet(ss.sheets.first).to_csv)
  end

  def ensure_csv!(file_path)
    file_path = file_path.path if file_path.is_a?(Tempfile)
    type = mime_type(file_path)

    # check mime is correct before uploading
    accept = ['text/', 'text/plain', 'text/csv',  'application/csv', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
    unless type.start_with?(*accept)
      error!({ error: "File given is not a csv file - detected #{type}" }, 403)
    end

    # Convert xls files to csv...
    if type.start_with? 'application/vnd.ms-excel'
      excel_to_csv file_path, :xls
    elsif type.start_with? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      excel_to_csv file_path, :xlsx
    else
      FileHelper.ensure_utf8_code file_path, true
    end
  end

  def mime_in_list?(file, type_list)
    type = mime_type(file)

    # check mime is correct before uploading
    type.start_with?(*type_list)
  end

  def check_mime_against_list!(file, expect, type_list)
    unless mime_in_list?(file, type_list)
      error!({ error: "File given is not a #{expect} file - detected #{mime_type(file)}" }, 403)
    end
  end

  module_function :ensure_csv!
  module_function :check_mime_against_list!
  module_function :mime_in_list?
  module_function :mime_type
end
