require 'grape'

module Api
  class IotrackAuthenticatedApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Checkout a specific checkin record'
    params do
      requires :checkin_id, type: String, desc: 'The id of the checkin record'
    end
    put '/iotrack/checkout/:checkin_id' do
      unless authorise? current_user, User, :act_tutor
        error!({ error: "Only Tutors can perform this action" }, 403)
      end

      checkin = CheckIn.find params[:checkin_id]

      unless checkin.present?
        error!({ error: "Couldn't find a check-in with number #{params[:checkin]}" }, 403)
      end

      checkin.checkout_at = Time.zone.now
      checkin.save

      {
        id: checkin.id,
        card: checkin.id_card.id,
        seat: checkin.seat,
        username: checkin.id_card.user.present? ? checkin.id_card.user.username : nil
      }
    end

    desc 'Get checked in students for a room'
    params do
      requires :room_number, type: String, desc: 'The room number to get checked in students for'
    end
    get '/iotrack/check-ins' do
      unless authorise? current_user, User, :act_tutor
        error!({ error: "Only Tutors can perform this action" }, 403)
      end

      room = Room.find_by room_number: params[:room_number]

      unless room.present?
        error!({ error: "Couldn't find a room with number #{params[:room_number]}" }, 403)
      end

      CheckIn.where(room: room).only_active.includes(id_card: :user).map do |checkin|
        {
          id: checkin.id,
          card: checkin.id_card.id,
          seat: checkin.seat,
          username: checkin.id_card.user.present? ? checkin.id_card.user.username : nil
        }
      end
    end

    desc 'Checkout Everyone in the room according to the provided parameters'
    params do
      requires :room_number, type: String, desc: 'The room number to checkout students from'
      optional :tutorial_id, type: String, desc: 'The Tutorial to leave its students checked in at to the room'
      optional :time_limit, type: Integer, desc: 'The max number of minutes to exclude check ins after'
      at_least_one_of :tutorial_id, :time_limit
    end
    put '/iotrack/checkout-everyone-not-in-tutorial' do
      room = Room.find_by room_number: params[:room_number]

      unless room.present?
        error!({ error: "Couldn't find a room with number #{params[:room_number]}" }, 403)
      end

      tutorial = nil

      if params[:tutorial_id].present?
        tutorial = Tutorial.find params[:tutorial_id]

        unless tutorial.present?
          error!({ error: "Couldn't find a tutorial with id #{params[:tutorial_id]}" }, 403)
        end

        unless tutorial.in_session
          error!({ error: 'This is only allowed when the tutorial is in session' }, 403)
        end
      end

      room.checkout_all tutorial, params[:time_limit]
    end

    desc 'Assign seat to a check in record'
    params do
      requires :room_number, type: String, desc: 'The room number that the seat is at'
      requires :seat_number, type: String, desc: 'The seat number to assign to the check in record'
    end
    put '/iotrack/assing-seat' do
      unless current_user.is_student?
        error!({ error: "Only Students can perform this action" }, 403)
      end

      room = Room.find_by room_number: params[:room_number]

      unless room.present?
        error!({ error: "Couldn't find a room with number #{params[:room_number]}" }, 403)
      end

      unless (checkin = CheckIn.only_active.includes(id_card: :user).where(room: room).where(user: { id: current_user.id }).first).present?
        error!({ error: "Couldn't find an active check in record for you at room #{params[:room_number]}. If you did swipe your card, your student card might not be linked to your OnTrack account. Please ask your tutor for help." }, 403)
      end

      checkin.seat = params[:seat_number]
      checkin.save
    end

    desc 'Assign user to Id card'
    params do
      requires :id_card_id, type: String, desc: 'The ID of an ID Card'
      requires :username, type: String, desc: 'The username of the student'
    end
    put '/iotrack/assign-user-to-id-card' do
      unless authorise? current_user, User, :act_tutor
        error!({ error: "Only Tutors can perform this action" }, 403)
      end

      id_card = IdCard.find params[:id_card_id]

      unless id_card.present?
        error!({ error: "Couldn't find an id card with id #{params[:id_card_id]}" }, 403)
      end

      user = User.find_by username: params[:username]

      unless user.present?
        error!({ error: "Couldn't find a user with username #{params[:username]}" }, 403)
      end

      id_card.user = user
      id_card.save
      
      {
        id: checkin.id,
        card: checkin.id_card.id,
        seat: checkin.seat,
        username: checkin.id_card.user.username
      }
    end
  end
end
