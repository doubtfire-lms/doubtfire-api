class SeedRoomData < ActiveRecord::Migration
  def change
    Tutorial.uniq.pluck('meeting_location').each do |room|
      room_record = Room.create(room_number: room)
      Tutorial.where(meeting_location: room).update_all(room_id: room_record)
    end
  end
end
