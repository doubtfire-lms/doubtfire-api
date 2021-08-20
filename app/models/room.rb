class Room < ApplicationRecord
  has_many :check_ins
  has_many :tutorials

  def checkout_all(except_tutorial_id, time_limit)
    to_checkout = check_ins.only_active
    if except_tutorial_id.present?
      exclude = Tutorial.where(id: except_tutorial_id).joins(projects: {user: {check_ins: :room}}).where(room: {room_number: room_number}, check_ins: {checkout_at: nil}).select('check_ins.id as cid').map {|record| record['cid']}
      to_checkout = to_checkout.where.not(id: exclude)
    end

    if time_limit.present?
      to_checkout = to_checkout.where("checkin_at < ?", Time.zone.now - time_limit.minutes)
    end

    to_checkout.update_all checkout_at: Time.zone.now
  end
end
