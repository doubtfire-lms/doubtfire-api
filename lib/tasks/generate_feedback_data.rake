namespace :db do

  desc "Generate feedback chips"
  task generate_feedback_chips: :environment do
    require 'faker'

    units = Unit.limit(5)
    task_definitions = TaskDefinition.limit(5)

    units.each do |unit|
      FactoryBot.create_list(:learning_outcome, 3, context_type: 'Unit', context_id: unit.id)
    end
    task_definitions.each do |task_definition|
      FactoryBot.create_list(:learning_outcome, 3, context_type: 'TaskDefinition', context_id: task_definition.id)
    end

    LearningOutcome.all.each do |lo|
      # create 4 top level group chips
      group_chips = FactoryBot.create_list(:feedback_group_chip, 2, learning_outcome_id: lo.id)
      nested_group_chips = FactoryBot.create_list(:feedback_group_chip, 2, learning_outcome_id: lo.id)

      # create 2 template chips for each group chip
      group_chips.each do |group_chip|
        FactoryBot.create_list(:feedback_template_chip, 2, parent_chip_id: group_chip.id, learning_outcome_id: lo.id)
      end

      # create 2 group chips for each nested group chip
      nested_group_chips.each do |nested_group_chip|
        double_nested_group_chips = FactoryBot.create_list(:feedback_group_chip, 2, parent_chip_id: nested_group_chip.id, learning_outcome_id: lo.id)
        # create 2 template chips for each double nested group chip
        double_nested_group_chips.each do |double_nested_group_chip|
          FactoryBot.create_list(:feedback_template_chip, 2, parent_chip_id: double_nested_group_chip.id, learning_outcome_id: lo.id)
        end
      end
    end

    puts "Dummy data generated"
  end

  desc "Check generated data"
  task print_dummy_data: :environment do
    puts "Printing all testing data...\n\n"

    puts "Feedback Group Chips:"
    Feedback::FeedbackGroupChip.all.each do |chip|
      puts "Feedback Group Chip: #{chip.id} (#{chip.chip_text}), Parent Chip Id: #{chip.parent_chip_id}, Learning Outcome: #{chip.learning_outcome_id}"
    end

    puts "Feedback Template Chips:"
    Feedback::FeedbackTemplateChip.all.each do |chip|
      puts "Feedback Template Chip: #{chip.id} (#{chip.chip_text}), Parent Chip Id: #{chip.parent_chip_id}, Learning Outcome: #{chip.learning_outcome_id}"
    end

    puts "Feedback Template Chips: #{Feedback::FeedbackTemplateChip.count}"
    puts "Feedback Group Chips: #{Feedback::FeedbackGroupChip.count}"
    puts "Dummy data printed"
  end
end
