require 'test_helper'

class StudentsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_check_in_student_with_unassigned_card_returns_correct_response
    room = FactoryBot.create(:room)
    card = FactoryBot.create(:id_card)

    json_data = { card_id: card.card_number, room_number: room.room_number }

    post_json '/api/iotrack/check-in-out', json_data

    assert_equal 201, last_response.status
    assert_equal last_response_body['checked_out'], false
    assert_equal last_response_body['need_user_assignment'], true
  end

  def test_check_in_creates_new_id_card_record_if_it_does_not_exist
    room = FactoryBot.create(:room)

    json_data = { card_id: 'non-existent-card', room_number: room.room_number }

    post_json '/api/iotrack/check-in-out', json_data

    assert_equal 201, last_response.status
    assert_equal last_response_body['checked_out'], false
    assert_equal last_response_body['need_user_assignment'], true
    assert_equal IdCard.find_by(card_number: 'non-existent-card').present?, true
  end

  def test_check_in_records_correct_checkin_at_timestamp
    room = FactoryBot.create(:room)
    card = FactoryBot.create(:id_card)

    json_data = { card_id: card.card_number, room_number: room.room_number }

    freeze_time
    expected_time = Time.zone.now

    post_json '/api/iotrack/check-in-out', json_data

    assert_equal 201, last_response.status
    assert_equal last_response_body['checked_out'], false
    assert_equal CheckIn.first.checkin_at, expected_time
  end

  def test_check_out_returns_correct_response
    room = FactoryBot.create(:room)
    card = FactoryBot.create(:id_card)
    checkin = FactoryBot.create(:check_in, room: room, id_card: card)

    json_data = { card_id: card.card_number, room_number: room.room_number }

    post_json '/api/iotrack/check-in-out', json_data

    assert_equal 201, last_response.status
    assert_equal last_response_body['checked_out'], true
  end

  def test_check_out_records_correct_checkout_timestamp
    room = FactoryBot.create(:room)
    card = FactoryBot.create(:id_card)
    checkin = FactoryBot.create(:check_in, room: room, id_card: card)

    json_data = { card_id: card.card_number, room_number: room.room_number }

    freeze_time
    expected_time = Time.zone.now

    post_json '/api/iotrack/check-in-out', json_data

    assert_equal 201, last_response.status
    assert_equal last_response_body['checked_out'], true
    assert_equal checkin.reload.checkout_at, expected_time
  end

  # def test_seat_assignment_records_seat_correctly_when_there_is_a_current_checkin_session
  #   # TODO
  # end

  # def test_seat_assignment_fails_when_there_is_no_current_checkin_session
  #   # TODO
  # end
end
