require 'grape'

module Api
  class IotrackAuthenticatedApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
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
          card: checkin.id_card.id,
          user: checkin.id_card.user.present? ? checkin.id_card.user.username : nil
        }
      end
    end

    # TODO: checkout every one in the room not in this tutorial
    desc 'Checkout Everyone in the room who is not assigned to this tutorial'
    params do
      requires :room_number, type: String, desc: 'The room number to checkout students from'
      optional :tutorial_id, type: String, desc: 'The Tutorial to leave its students checked at to the room'
      optional :time_limit, type: Integer, desc: 'The max number of minutes ..'
    end
    post '/iotrack/checkout-everyone-not-in-tutorial' do
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
    post '/iotrack/assing-seat' do
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
    post '/iotrack/assign-user-to-id-card' do
      unless authorise? current_user, User, :act_tutor
        error!({ error: "Only Tutors can perform this action" }, 403)
      end

      id_card = IdCard.find params[:id_card_id]

      unless id_card.present?
        error!({ error: "Couldn't find an id card with id #{params[:id_card_id]}" }, 403)
      end

      user = User.find_by username params[:username]

      unless user.present?
        error!({ error: "Couldn't find a user with username #{params[:username]}" }, 403)
      end

      id_card.user = user
    end
  end
end
