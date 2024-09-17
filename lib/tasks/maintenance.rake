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
    # Next returns from rake tasks
    next if archive_period <= 1.year

    units = Unit.where(archived: false).where('end_date < :archive_before', archive_before: DateTime.now - archive_period)
    unit_ids = units.pluck(:id)

    loop do
      puts "Are you happy to archive the following units?"
      units.find_each do |unit|
        puts("#{unit.id}: #{unit.detailed_name}") if unit_ids.include?(unit.id)
      end

      puts "Please enter any unit IDs you would like to remove from the list, separated by commas"
      response = $stdin.gets.chomp
      break if response.blank?
      unit_ids_to_exclude = response.split(',').map(&:to_i)

      unit_ids = unit_ids.excluding(unit_ids_to_exclude)

      break if unit_ids.empty?
    end

    # Next returns from rake tasks
    next if unit_ids.empty?

    puts "Proceed? (Yes/No): "
    response = $stdin.gets.chomp
    next unless response == 'Yes'

    Unit.where(id: unit_ids).preload(projects: [:user, { tasks: :task_definition }]).find_each do |unit|
      unit.archive_submissions($stdout)
      unit.update(archived: true)
    end
  end
end
