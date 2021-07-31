require 'grape'
require 'project_serializer'

module Api
  class IotrackPublicApi < Grape::API

    desc 'Checks in or out the student to the room'
    params do
      requires :card_id, type: String, desc: 'The card id for the student wanting to check in/out'
      requires :room_number, type: String, desc: 'The room number to check the student into/out from'
    end
    post '/iotrack/check-in-out' do
      id_card = IdCard.find_or_create_by card_number: params[:card_id]
      room = Room.find_by room_number: params[:room_number]

      unless room.present?
        error!({ error: "Couldn't find a room with number #{params[:room_number]}" }, 403)
      end

      if record = CheckIn.where(id_card: id_card, room: room).only_active.first.present?
        record.checkout_at = Time.zone.now
        record.save
      else
        record = CheckIn.create(id_card: id_card, room: room, checkin_at: Time.zone.now)
      end

      {
        checked_out: record.checkout_at.present?,
        need_user_assignment: record.id_card.user.nil?
      }
    end
  end
end
