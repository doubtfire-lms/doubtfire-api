# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

class DatabasePopulator

  def initialize
    # Set up our caches
    puts '-> Setting up populate cache'
    @role_cache = {}
    @user_cache = []
  end

  #
  # Generate some roles
  #
  def generate_user_roles
    puts "-> Generating User Roles"
    roles = [
      :student,
      :tutor,
      :convenor,
      :admin
    ]

    roles.each do |role|
      puts "--> Adding #{role}"
      @role_cache[role] = Role.create!(name: role.to_s.titleize)
    end
  end

  #
  # Generate some users
  #
  def generate_users
    puts "--> Generating Users"

    if @role_cache.length == 0
      throw "Call generate_user_roles first"
    end

    users = {
      acain:              {first_name: "Andrew",         last_name: "Cain",                 nickname: "Macite",         role_id: Role.admin_id},
      jrenzella:          {first_name: "Jake",           last_name: "Renzella",             nickname: "FactoryBoy<3",   role_id: Role.convenor_id},
      rwilson:            {first_name: "Reuben",         last_name: "Wilson",               nickname: "FactoryGurl</3", role_id: Role.tutor_id},
      acummaudo:          {first_name: "Alex",           last_name: "Cummaudo",             nickname: "Doubtfire Dude", role_id: Role.student_id},

    }
    users.each do |user_key, profile|
      puts "--> Generating #{user_key}"
      username = user_key.to_s

      profile[:email]     ||= "#{username}@doubtfire.com"
      profile[:username]  ||= username

      user = User.create!(profile.merge({password: 'password', password_confirmation: 'password'}))
      @user_cache.push user
    end
  end
end

p = DatabasePopulator.new

p.generate_user_roles()
p.generate_users()