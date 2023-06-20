namespace :submission do
  desc 'Compress the PDF files for the submissions'

  def logger
    Rails.logger
  end

  task compress_pdfs: :environment do
    logger.info 'Starting compress pdf'
    puts 'Starting compress pdf'

    Unit.where('active').each do |u|
      u.tasks.where('portfolio_evidence is not NULL').each do |t|
        if File.exist?(t.portfolio_evidence_path) && File.size?(t.portfolio_evidence_path) >= 2_200_000
          puts "Compressing #{t.portfolio_evidence_path}"
          FileHelper.compress_pdf(t.portfolio_evidence_path)
        end
      end
    end

    logger.info 'End compress pdf'
  end

  task compress_portfolios: :environment do
    logger.info 'Starting compress portfolios'
    puts 'Starting compress portfolios'

    Unit.where('active').each do |u|
      puts "Unit #{u.name}"
      u.projects.select { |p| p.portfolio_exists? && File.exist?(p.portfolio_path) && File.size?(p.portfolio_path) >= 20_000_000 }.each do |p|
        puts "    Compressing #{p.portfolio_path}"
        FileHelper.compress_pdf(p.portfolio_path)
      end
    end

    logger.info 'End compress portfolios'
  end

  task recreate_large_pdfs: :environment do
    if is_executing?
      puts 'Skip recreate large pdfs -- already executing'
      logger.info 'Cant recreate large pdf'
    else
      start_executing

      begin
        Unit.where('active').each do |u|
          u.tasks.where('portfolio_evidence is not NULL').each do |t|
            pdf_file = t.final_pdf_path
            next unless pdf_file && File.exist?(pdf_file) && File.size?(pdf_file) >= 2_200_000

            puts "  Recreating #{t.portfolio_evidence_path} was #{File.size?(pdf_file)}"
            t.move_done_to_new
            t.convert_submission_to_pdf
            puts "  ... now #{File.size?(pdf_file)}"
          end
        end
      ensure
        end_executing
      end
    end
  end
end
