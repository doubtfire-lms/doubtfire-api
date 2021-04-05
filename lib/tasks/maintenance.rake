require_all 'lib/helpers'

namespace :maintenance do
  desc 'Cleanup temporary files'
  task cleanup: [:environment] do
    path = FileHelper.tmp_file_dir
    
    if Rails.env.development?
      time_offset = 1.minute
    else
      time_offset = 3.hours
    end

    Dir.foreach(path) do |item|
      fname = "#{path}#{item}"
      next if File.directory?(fname)
      if File.mtime(fname) < DateTime.now - time_offset
        begin
          File.delete(fname)
        rescue
          puts "Failed to remove temporary file: #{fname}"
        end
      end 
    end
  end
end
