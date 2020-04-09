class MoveAuthTokenOutOfUsers < ActiveRecord::Migration
  #TODO: Fix down... add index to authentication token, also ensure token is copied back to user

  def up
    create_table :auth_tokens do |t|
      t.string          :authentication_token,  null: false,  limit: 255
      t.datetime        :auth_token_expiry,     null: false
      t.integer         :user_id,               null: false
    end
    add_reference   :auth_tokens, :users, index: true
    add_foreign_key :auth_tokens, :users

    User.all.
      map { |u| { token: u.authentication_token, user: u.id, expiry: u.auth_token_expiry } }.
      select { |d| d[:token].present? }.
      each do |d| 
        AuthToken.create(authentication_token: d[:token], auth_token_expiry: d[:expiry], user_id: d[:user])
      end

    remove_column :users, :authentication_token
    remove_column :users, :auth_token_expiry
  end

  def down
    add_column :users, :authentication_token, :string,    limit: 255
    add_column :users, :auth_token_expiry,    :datetime

    byebug

    AuthToken.where("auth_token_expiry > :time", time: Time.zone.now).
      each do |token| 
        u = User.find(token.user_id)
        u.authentication_token = token.authentication_token
        u.auth_token_expiry = token.auth_token_expiry
        u.save!
      end

    drop_table :auth_tokens
  end
end
