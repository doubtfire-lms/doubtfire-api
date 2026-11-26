namespace :unit_content_sites do
  desc 'Populate content versions and extract unit content archives for serving. Safe to re-run; FORCE=1 re-extracts all.'
  task extract_all: :environment do
    force = ENV['FORCE'].present?
    extracted = 0
    up_to_date = 0
    failures = []

    UnitContentSite.includes(:unit).find_each do |site|
      unless site.archive_path.present? && File.file?(site.archive_path)
        puts "site #{site.id}: archive missing, skipped"
        next
      end

      # The version is a hash of the archive and its root dir, so this also
      # picks up archives that were replaced outside the app.
      version = UnitContentSite.content_version_for(site.archive_path, site.root_dir)

      if site.content_version == version && File.directory?(site.served_dir) && !force
        up_to_date += 1
        next
      end

      # Set in memory first - the HTML rewrite builds versioned URLs from it -
      # but only persist once the extraction succeeded. A failure then leaves the
      # old version stored, so the next run retries instead of assuming success.
      site.content_version = version
      site.extract_for_serving!
      site.save!
      extracted += 1
      puts "site #{site.id}: extracted"
    rescue StandardError => e
      puts "site #{site.id}: failed - #{e.message}"
      failures << site.id
    end

    puts "#{extracted} extracted, #{up_to_date} already up to date, #{failures.length} failed. Nothing deleted."
    abort "Failed: #{failures.join(', ')}" if failures.any?
  end
end
