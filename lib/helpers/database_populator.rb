require 'populator'
require 'faker'
require 'bcrypt'
require 'json'

#
# This class populates data in the database
#
class DatabasePopulator
  #
  # Initialiser sets up the cache required for the populator.
  # Scale is set to :small by default.
  #
  def initialize(scale = :small)
    # Set up our caches
    puts '-> Setting up populate cache'
    @role_cache = {}
    generate_user_roles()
    @user_cache = {}
    # Set up the scale
    scale_data = {
      small: {
        min_students: 5,
        delta_students: 2,
        few_tasks: 5,
        some_tasks: 10,
        many_task: 20,
        few_tutorials: 1,
        some_tutorials: 1,
        many_tutorials: 1,
        max_tutorials: 4
      },
      large: {
        min_students: 15,
        delta_students: 7,
        few_tasks: 10,
        some_tasks: 30,
        many_task: 50,
        few_tutorials: 1,
        some_tutorials: 2,
        many_tutorials: 4,
        max_tutorials: 20
      }
    }
    accepted_scale_types = scale_data.keys
    unless accepted_scale_types.include?(scale)
      throw "Invalid scale value '#{scale}'. Acceptable values are: #{accepted_scale_types.join(", ")}"
    else
      puts '-> Scale is set to #{scale}'
    end
    @scale = scale_data[scale]
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
    users = {
      acain:      {first_name: "Andrew",  last_name: "Cain",      nickname: "Macite",         role_id: Role.admin_id},
      jrenzella:  {first_name: "Jake",    last_name: "Renzella",  nickname: "FactoryBoy<3",   role_id: Role.convenor_id},
      rwilson:    {first_name: "Reuben",  last_name: "Wilson",    nickname: "FactoryGurl</3", role_id: Role.tutor_id},
      acummaudo:  {first_name: "Alex",    last_name: "Cummaudo",  nickname: "Doubtfire Dude", role_id: Role.student_id},
    }
    users.each do |user_key, profile|
      puts "--> Generating #{user_key}"
      username = user_key.to_s

      profile[:email]     ||= "#{username}@doubtfire.com"
      profile[:username]  ||= username

      user = User.create!(profile.merge({
        password: 'password',
        password_confirmation: 'password'
      }))

      @user_cache[user_key] = user
    end
  end

  #
  # Generates some units
  #
  def generate_units
    # Set sizes from scale
    some_tasks = @scale[:some_tasks]
    many_tasks = @scale[:many_tasks]
    some_tutorials = @scale[:some_tutorials]
    many_tutorials = @scale[:many_tutorials]

    # Define the basic unit details here
    unit_data = {
      intro_prog: {
        code: "COS10001",
        name: "Introduction to Programming",
        convenors: [ :acain ],
        tutors: [
          { user: :acain, num: many_tutorials},
          { user: :rwilson, num: many_tutorials},
          { user: :acummaudo, num: some_tutorials},
          { user: :jrenzella, num: some_tutorials}
        ],
        num_tasks: some_tasks,
        ilos: rand(0..3),
        students: [ ]
      },
      gameprog: {
        code: "COS30243",
        name: "Game Programming",
        convenors: [ :acummaudo ],
        tutors: [
          { user: :cwoodward, num: some_tutorials },
        ],
        num_tasks: some_tasks,
        ilos: rand(0..3),
        students: [ :acain, :jrenzella, :rwilson ]
      },
    }

    # Run through the unit_details and initialise their data
    unit_data.each do | unit_key, unit_details |
      puts "------> #{unit_details[:code]}"
      unit = Unit.create!(
        code: unit_details[:code],
        name: unit_details[:name],
        description: Populator.words(10..15),
        start_date: Time.zone.now  - 6.weeks,
        end_date: 13.weeks.since(Time.zone.now - 6.weeks)
      )

      # Assign the convenors for this unit
      unit_details[:convenors].each do | user_key |
        puts "------> Adding convenor #{user_key} for #{unit_details[:code]}"
        unit.employ_staff(@user_cache[user_key], Role.convenor)
      end
    end
  end
end
