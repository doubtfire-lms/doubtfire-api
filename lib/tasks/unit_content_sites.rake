namespace :unit_content_sites do
  desc 'Extract and prepare all existing unit content archives for direct serving'
  task extract_all: :environment do
    failures = []

    UnitContentSite.includes(:unit).find_each do |site|
      print "Extracting unit content site #{site.id}... "
      site.extract_for_serving!
      puts 'done'
    rescue StandardError => e
      puts "failed (#{e.message})"
      failures << [site.id, e.message]
    end

    next if failures.empty?

    abort "Failed to extract #{failures.length} unit content site(s): #{failures.map(&:first).join(', ')}"
  end
end
