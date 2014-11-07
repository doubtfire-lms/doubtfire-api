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

  # Reuben 07.11.14: Rake script for setting all exisiting portfolio production dates

  task set_portfolio_production_date:  :environment do
    logger.info 'Setting portfolio production dates'
      
    Project.where("portfolio_production_date is null").select{|p| p.portfolio_available}.each{|p| p.portfolio_production_date = DateTime.now;p.save}
  end
end