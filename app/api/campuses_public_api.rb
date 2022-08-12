require 'grape'

class CampusesPublicApi < Grape::API
  desc "Get a campus details"
  get '/campuses/:id' do
    campus = Campus.find(params[:id])
    present campus, with: Entities::CampusEntity
  end

  desc 'Get all the Campuses'
  get '/campuses' do
    present Campus.all, with: Entities::CampusEntity
  end
end
