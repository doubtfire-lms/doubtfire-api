namespace :submission do
  desc "Compress the PDF files for the submissions"

  def logger
    Rails.logger
  end

  task compress_pdfs:  :environment do
    logger.info 'Starting compress pdf'
    puts 'Starting compress pdf'

  	Unit.where('active').each do |u|
      u.tasks.where('portfolio_evidence is not NULL').each do |t|
        if File.exists?(t.portfolio_evidence) && File.size?(t.portfolio_evidence) >= 22000000
          puts "Compressing #{t.portfolio_evidence}"
          FileHelper.compress_pdf(t.portfolio_evidence)
        end
      end
    end

    logger.info 'End compress pdf'      
  end

end
