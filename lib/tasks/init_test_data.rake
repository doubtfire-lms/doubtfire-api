#
namespace :db do
  desc "Setup the database for minitests"

  task init_test_data:  :environment do
    def setup_cache
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
        puts user[:username]
        @user_cache.push user
      end
    end

    def generate_convenors(unit_details, unit)
      unit_details[:convenors].each do | user_key |
        puts "------> Adding convenor #{user_key} for #{unit_details[:code]}"
        puts user_key
        unit.employ_staff(@user_cache.find {|user| user[:username] = user_key}, Role.convenor)
      end
    end

    def generate_units
      some_tasks = 5
      many_tasks = 10
      some_tutorials = 2
      many_tutorials = 4

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

      unit_data.each do | unit_key, unit_details |
        puts "------> #{unit_details[:code]}"
        unit = Unit.create!(
          code: unit_details[:code],
          name: unit_details[:name],
          description: Populator.words(10..15),
          start_date: Time.zone.now  - 6.weeks,
          end_date: 13.weeks.since(Time.zone.now - 6.weeks)
        )

        generate_convenors(unit_details, unit)
      end
    end

    setup_cache()
    generate_user_roles()
    generate_users()
    generate_units()
  end
end
