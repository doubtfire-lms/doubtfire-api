namespace :submission do
  desc "Generate PDF files for submissions"

  def logger
  	Rails.logger
  end

  task generate_pdfs:  :environment do
    logger.info 'Starting generate pdf'
	  	
  	PortfolioEvidence.process_new_to_pdf
  end
end