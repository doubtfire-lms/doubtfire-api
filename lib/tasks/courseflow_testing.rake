namespace :db do

  desc "check courseflow data"
  task check_courseflow_data: :environment do
    # Check that the unit definitions have been populated
    unit_definitions = UnitDefinition.all
    puts "Unit Definitions: #{unit_definitions.count}"
    unit_definitions.each do |unit_definition|
      puts "Unit Definition: #{unit_definition.name}"
      puts "Description: #{unit_definition.description}"
      puts "Code: #{unit_definition.code}"
      puts "Version: #{unit_definition.version}"
      puts "Units: #{unit_definition.units.count}"
    end
  end

  desc "clear courseflow data"
  task clear_courseflow_data: :environment do
    # Clear existing data from database
    old_units = Unit.where.not(unit_definition_id: nil)
    puts "Deleting #{old_units.count} units"
    old_units.destroy_all
    puts "Deleting #{UnitDefinition.count} unit definitions"
    UnitDefinition.destroy_all
  end

  desc "Populate the courseflow databases with dummy data"
  task populate_courseflow_data: :environment do
    require 'faker'

    # Clear existing data from database
    old_units = Unit.where.not(unit_definition_id: nil)
    puts "Deleting #{old_units.count} units"
    old_units.destroy_all
    puts "Deleting #{UnitDefinition.count} unit definitions"
    UnitDefinition.destroy_all

    unit_names = [
      "Information Technology", "Programming", "Web Development", "Data Science", "Cyber Security"
    ]

    unit_descriptions = [
      "Introduction to Information Technology", "Introduction to Programming", "Introduction to Web Development", "Introduction to Data Science", "Introduction to Cyber Security"
    ]

    course_codes = [
      "SIT101", "SIT102", "SIT103", "SIT104", "SIT105"
    ]

    course_versions = [
      "1.0", "1.1", "1.2", "1.3", "1.4"
    ]

    # Use factorybot to create new unit definitions
    # unit_definitions = FactoryBot.create_list(:unit_definition, 5)
    5.times do
      puts "Creating new unit definitions"
      unit_definition = UnitDefinition.create(
        name: unit_names.sample,
        description: unit_descriptions.sample,
        code: course_codes.sample,
        version: course_versions.sample
      )

      if unit_definition.persisted?
        puts "Unit Definition: #{unit_definition.name}"
        puts "Description: #{unit_definition.description}"
        puts "Code: #{unit_definition.code}"
        puts "Version: #{unit_definition.version}"
        puts "Unit definition #{unit_definition.id} created successfully"

        # Use factory bot to create the associated units
        FactoryBot.create_list(:unit, 3, name: unit_definition.name, description: unit_definition.description, unit_definition_id: unit_definition.id)
      else
        puts "Unit definition not created"
      end
    end

    puts "Database filled with courseflow data"
    puts "Unit Definitions: #{UnitDefinition.count}"
  end

  desc "Populate the courseflow db with fixed unit definitions"
  task populate_fixed_courseflow_data: :environment do
    require 'faker'

    # Clear existing data from database
    old_units = Unit.where.not(unit_definition_id: nil)
    puts "Deleting #{old_units.count} units"
    old_units.destroy_all
    puts "Deleting #{UnitDefinition.count} unit definitions"
    UnitDefinition.destroy_all

    # Create new unit definitions
    unit_definitions = [
      { name: "Computer Systems", code: "SIT111", version: "1.0" },
      { name: "Discrete Mathematics", code: "SIT192", version: "1.0" },
      { name: "Data Science Concepts", code: "SIT112", version: "1.0" },
      { name: "Introduction to Programming", code: "SIT102", version: "1.0" },

      { name: "Object-Oriented Development", code: "SIT232", version: "1.0" },
      { name: "Database Fundamentals", code: "SIT103", version: "1.0" },
      { name: "Linear Algebra for Data Analysis", code: "SIT292", version: "1.0" },
      { name: "Computer Networks and Communication", code: "SIT202", version: "1.0" },

      { name: "Computer Intelligence", code: "SIT215", version: "1.0" },
      { name: "Data Structures and Algorithms", code: "SIT221", version: "1.0" },
      { name: "Gamified Media", code: "ALM201", version: "1.0" },
      { name: "Global Media", code: "ALM215", version: "1.0" },

      { name: "Professional Practice", code: "SIT344", version: "1.0" },
      { name: "Team Project (A) - Project Management and Practices", code: "SIT374", version: "1.0" },
      { name: "Team Project (B) - Execution and Delivery", code: "SIT378", version: "1.0" },
      { name: "Concurrent and Distributed Programming", code: "SIT315", version: "1.0" },

      { name: "Computer Networks and Communication", code: "SIT202", version: "1.0" },
      { name: "Cyber Security Management", code: "SIT284", version: "1.0" },
      { name: "Machine Learning", code: "SIT307", version: "1.0" },
      { name: "Full Stack Development: Secure Backend Services", code: "SIT331", version: "1.0" }
    ]

    unit_definitions.each do |unit_definition|
      new_unit_definition = UnitDefinition.create(
        name: unit_definition[:name],
        description: Faker::Lorem.paragraph(sentence_count: 1), # Generates a random description for the definitions
        code: unit_definition[:code],
        version: unit_definition[:version]
      )
      puts "Created Unit Definition: #{new_unit_definition.name}"
    end
  end
end
