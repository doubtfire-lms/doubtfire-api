require 'test_helper'

class StudentsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_check_in_student_records_correct_data
    room = FactoryBot.create(:room)
    id_card = FactoryBot.create(:id_card)

    json_data = { card_id: id_card.card_number, room: room.room_number }

    post_json '/api/iotrack/check-in', json_data

    assert_equal 200, last_response.status
    assert_equal room.id, last_response_body.room_id
    assert_equal id_card.id, last_response_body.id_card_id
    assert_equal last_response_body.checkout_at, nil
    assert_equal last_response_body.seat, nil
    # TODO: Test that the timestamp is correct
  end

  def test_check_in_fails_when_there_is_a_current_checkin_session
    room = FactoryBot.create(:room)
    id_card = FactoryBot.create(:id_card)
    checkin = FactoryBot.create(:check_in, room: room, id_card: id_card)

    json_data = { card_id: id_card.card_number, room: room.room_number }

    post_json '/api/iotrack/check-in', json_data

    assert_equal 403, last_response.status
    assert_equal last_response_body.error, 'A current checkin session in this room for this person exists'
  end

  def test_check_out_student_sets_checkout_timestamp_correctly
    # TODO
  end

  def test_check_out_fails_when_there_is_no_current_checkin_session
    # TODO
  end

  def test_seat_assignment_records_seat_correctly_when_there_is_a_current_checkin_session
    # TODO
  end

  def test_seat_assignment_fails_when_there_is_no_current_checkin_session
    # TODO
  end
end
