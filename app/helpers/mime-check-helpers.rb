module MimeCheckHelpers

  def ensure_csv!(file_path)
    fm = FileMagic.new(FileMagic::MAGIC_MIME)
    mime_type = fm.file(file_path.path)

    # check mime is correct before uploading
    accept = ['text/', 'text/plain', 'text/csv']
    if not mime_type.start_with?(*accept)
      error!({"error" => "File given is not a csv file - detected #{mime_type}"}, 403)
    end
  end

  module_function :ensure_csv!
end


