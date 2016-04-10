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

  def generate_units
    min_students = 5
    delta_students = 2
    few_tasks = 5
    some_tasks = 10
    many_task = 20
    few_tutorials = 1
    some_tutorials = 1
    many_tutorials = 1
    max_tutorials = 4
    unit_data = {
      intro_prog: {
        code: "COS10001",
        name: "Introduction to Programming",
        convenors: [ :acain, :cwoodward ],
        tutors: [
          { user: :acain, num: many_tutorials},
          { user: :cwoodward, num: many_tutorials},
          { user: :ajones, num: many_tutorials},
          { user: :rwilson, num: many_tutorials},
          { user: :acummaudo, num: some_tutorials},
          { user: :akihironoguchi, num: many_tutorials},
          { user: :joostfunkekupper, num: many_tutorials},
          { user: :angusmorton, num: some_tutorials},
          { user: :cliff, num: some_tutorials},
        ],
        num_tasks: some_tasks,
        ilos: rand(0..3),
        students: [ ]
      },
      oop: {
        code: "COS20007",
        name: "Object Oriented Programming",
        convenors: [ :acain, :cwoodward, :ajones, :acummaudo ],
        tutors: [
          { user: "tutor_1", num: few_tutorials },
          { user: :angusmorton, num: few_tutorials },
          { user: :akihironoguchi, num: few_tutorials },
          { user: :joostfunkekupper, num: few_tutorials },
        ],
        num_tasks: many_task,
        ilos: rand(0..3),
        students: [ :cliff ]
      },
      ai4g: {
        code: "COS30046",
        name: "Artificial Intelligence for Games",
        convenors: [ :cwoodward ],
        tutors: [
          { user: :cwoodward, num: few_tutorials },
          { user: :cliff, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: rand(0..3),
        students: [ :acummaudo ]
      },
      gameprog: {
        code: "COS30243",
        name: "Game Programming",
        convenors: [ :cwoodward, :acummaudo ],
        tutors: [
          { user: :cwoodward, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: rand(0..3),
        students: [ :acain, :ajones ]
      },
    }

    unit_data.each do | unit_key, unit_details |
      puts "------> #{unit_details[:code]}"
      unit = Unit.create!(
        code: unit_details[:code],
        name: unit_details[:name],
        description: Populator.words(10..15),
        start_date: Time.zone.now  - 6.weeks,
        end_date: 13.weeks.since(Time.zone.now - 6.weeks)
      )
    end
  end
end

p = DatabasePopulator.new

p.generate_user_roles()
p.generate_users()
p.generate_units()
