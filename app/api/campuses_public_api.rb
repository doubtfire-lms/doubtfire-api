require 'grape'

module Api
  class CampusesPublicApi < Grape::API

    desc "Get a campus details"
    get '/campuses/:id' do
      campus = Campus.find(params[:id])
      campus
    end

    desc 'Get all the Campuses'
    get '/campuses' do
      Campus.all
    end
  end
end