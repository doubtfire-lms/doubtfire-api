require 'grape'

module Api
  class CampusesPublicApi < Grape::API

    desc "Get a campus details"
    get '/campuses/:id' do
      campus = Campus.find(params[:id])
      present campus, with: Api::Entities::CampusEntity
    end

    desc 'Get all the Campuses'
    get '/campuses' do
      present Campus.all, with: Api::Entities::CampusEntity
    end
  end
end
