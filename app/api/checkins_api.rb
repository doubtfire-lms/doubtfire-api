require 'grape'
require 'project_serializer'

module Api
  class CheckinsApi < Grape::API

    desc 'Checkin the student to the room'
    params do
      requires :card_id, type: String, desc: 'The card id for the student wanting to checkin'
      requires :room_number, type: String, desc: 'The room number to check the student into'
    end
    post '/iotrack/check-in' do
      id_card = IdCard.find_or_create_by card_number: params[:card_id]
      room = Room.find_by room_number: params[:room_number]

      unless room
        error!({ error: "Couldn't find a room with number #{params[:room_number]}" }, 403)
      end

      if CheckIn.where(id_card: id_card, room: room, checkout_at: nil).exists?
        error!({ error: 'A current checkin session in this room for this person exists' }, 403)
      end

      CheckIn.create(id_card: id_card, room: room, checkin_at: Time.zone.now)
    end

    # TODO: Authorisation
    desc 'Get checked in students for a room'
    params do
      requires :room_number, type: String, desc: 'The room number to get checked in students for'
      optional :include_checked_out, type: Boolean, desc: 'Also get students who checked out of the room recently'
    end
    get '/iotrack/check-ins' do
      room = Room.find_by room_number: params[:room_number]

      unless room
        error!({ error: "Couldn't find a room with number #{params[:room_number]}" }, 403)
      end

      result = if params[:include_checked_out].nil? || !params[:include_checked_out]
                 CheckIn.where(room: room).only_active
               else
                 CheckIn.where(room: room)
               end
    end
  end
end
