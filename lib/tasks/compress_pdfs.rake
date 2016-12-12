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
        if File.exist?(t.portfolio_evidence) && File.size?(t.portfolio_evidence) >= 2_200_000
          puts "Compressing #{t.portfolio_evidence}"
          FileHelper.compress_pdf(t.portfolio_evidence)
        end
      end
    end

    logger.info 'End compress pdf'
  end

  task compress_done: :environment do
    Unit.where('active').each do |u|
      u.tasks.where('portfolio_evidence is not NULL').each do |t|
        done_file = t.zip_file_path_for_done_task
        puts "Checking #{done_file}"
        next unless done_file && File.exist?(done_file) && File.size?(done_file) >= 2_200_000
        puts "Compressing #{t.portfolio_evidence}"
        t.move_done_to_new
        t.compress_new_to_done
      end
    end
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
            puts "  Recreating #{t.portfolio_evidence} was #{File.size?(pdf_file)}"
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
