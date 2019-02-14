require 'grape'

module Api
  class UnitRequests < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    desc 'Create unit request'  
    params do
           requires :unit_id, type: Integer, desc: 'Id of the unit'
           requires :user_id, type: Integer, desc: 'Id of the unit'
    end 
    post '/unitrequests' do
      unit = Unit.find(params[:unit_id])
      stud = User.find(params[:user_id])


      unit_request = UnitRequest.create!(unit_id: unit.id, user_id: stud.id, request_at: '2019-5-5', status: 'waiting') #unit.add_unit_request('stud')
      ApplicationMailer.send_email(stud,unit,'staff@deakin.edu.au')
      unit_request
  end
end
end