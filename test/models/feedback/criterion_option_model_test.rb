require 'test_helper'

#
# Tests for CriterionOption model objects - not accessed via API
#
class CriterionOptionModelTest < ActiveSupport::TestCase
    
    # Setup objects for testing
    setup do
        DatabaseCleaner.start
        @criterion = FactoryBot.create(:criterion)
        @task_status = TaskStatus.new
    end

    # Test you can create a valid criterion option
    def test_valid_criterion_option_creation
        criterion_option = CriterionOption.create(criterion: @criterion, task_status: @task_status)
        assert criterion_option.valid?
        criterion_option.resolved_message_text = Faker::Lorem.sentence
        assert criterion_option.valid?
        criterion_option.unresolved_message_text = Faker::Lorem.sentence
        assert criterion_option.valid?
    end

    # Test you cannot create an invalid criterion option
    def test_invalid_criterion_option_creation
        criterion_option = CriterionOption.new

        refute criterion_option.valid?
        criterion_option.resolved_message_text = Faker::Lorem.sentence
        refute criterion_option.valid?
        criterion_option.unresolved_message_text = Faker::Lorem.sentence
        refute criterion_option.valid?

        criterion_option.task_status = @task_status
        refute criterion_option.valid?
        criterion_option.criterion = @criterion
        assert criterion_option.valid?
        criterion_option.task_status = nil
        refute criterion_option.valid?

        refute criterion_option.save
    end
end
