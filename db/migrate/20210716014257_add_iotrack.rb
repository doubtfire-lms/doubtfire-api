class AddIotrack < ActiveRecord::Migration
  def change
    create_table :rooms do |t|
      t.string        :room_number,                null: false
    end

    create_table :id_cards do |t|
      t.integer        :user_id,                null: true
      t.string         :card_number,                null: false
    end

    create_table :check_ins do |t|
      t.integer       :id_card_id,           null: false
      t.integer       :room_id,             null: false
      t.string        :seat,                null: true
      t.datetime      :checkin_at,           null: false
      t.datetime      :checkout_at,          null: true
    end
  end
end
