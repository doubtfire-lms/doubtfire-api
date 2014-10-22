namespace :submission do
  desc "Generate PDF files for submissions"

  def logger
  	Rails.logger
  end

  task generate_pdfs:  :environment do
    logger.info 'Starting generate pdf'
	  	
  	PortfolioEvidence.process_new_to_pdf

  	projects_to_compile = Project.where(compile_portfolio: true)
  	projects_to_compile.each do | project |
  		begin
  	 		project.create_portfolio()
  	 	rescue Exception => e
  	 		logger.error "Failed creating portfolio for project #{project.id}!\n#{e.message}"
  	 	end
  	end
  end
end