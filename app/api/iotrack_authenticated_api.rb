require 'grape'
require 'project_serializer'

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
        error!({ error: "...." }, 403)
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

      # TODO: At least one of timie_limit or tutorial is required

      room.checkout_all tutorial, params[:time_limit]

      # MEETING: How would I know if the student is in the tutorial or not? Note that an ID Card is not necessarily attached to a student
    end
  end
end
