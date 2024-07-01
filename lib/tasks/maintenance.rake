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

    AuthToken.destroy_old_tokens
  end

  desc 'Remove PDFs from old submissions and archive units'
  task archive_submissions: [:environment] do
    archive_period = Doubtfire::Application.config.unit_archive_after_period
    return if archive_period <= 1.year

    Unit.where(archived: false).where('end_date < :archive_before', archive_before: DateTime.now - archive_period).find_each do |unit|
      puts "Are you sure you want to archive #{unit.detailed_name}? (Yes to confirm): "
      response = $stdin.gets.chomp

      next unless response == 'Yes'

      unit.archive_submissions($stdout)
      unit.update(archived: true)
    end
  end
end
