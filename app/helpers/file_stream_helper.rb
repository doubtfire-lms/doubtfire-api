module FileStreamHelper
  # Extract part of the contents so that is can be streamed to the client
  # file_path is the path to the file to be streamed
  # this will set the headers and return the content
  def stream_file(file_path)
    # Work out what part to return
    file_size = File.size(file_path)
    begin_point = 0
    end_point = file_size - 1

    # Was it asked for just a part of the file?
    if request.headers['Range']
      # indicate partial content
      status 206

      # extract part desired from the content
      if request.headers['Range'] =~ /bytes=(\d+)-(\d*)/
        begin_point = Regexp.last_match(1).to_i
        end_point = Regexp.last_match(2).to_i if Regexp.last_match(2).present?
      end

      end_point = file_size - 1 unless end_point < file_size - 1

      # Limit to 10MB chunks
      if end_point - begin_point + 1 > 10_485_760
        end_point = begin_point + 10_485_760
      end
    elsif file_size > 10_485_760
      # If the file is large, only return the first 1MB
      status 206
      begin_point = 0
      end_point = 10_485_760
    else
      sendfile file_path

      return
    end

    # Return the requested content
    content_length = end_point - begin_point + 1
    header['Access-Control-Expose-Headers'] = 'Content-Range,Accept-Ranges'
    header['Content-Range'] = "bytes #{begin_point}-#{end_point}/#{file_size}"
    header['Content-Length'] = content_length.to_s
    header['Accept-Ranges'] = 'bytes'

    env['api.format'] = :binary

    # Read the binary data and return
    body = File.binread(file_path, content_length, begin_point)
  end

  module_function :stream_file
end
