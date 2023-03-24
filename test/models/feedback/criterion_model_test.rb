require 'test_helper'

#
# Tests for Criterion model objects - not accessed via API
#
class CriterionModelTest < ActiveSupport::TestCase
    def app
        Rails.application
    end
    
    # Test you can create a valid criterion
    def test_criterion_creation
        td = FactoryBot.create(:task_definition)
        stage = Stage.create(task_definition: td, title: 'Stage 1', order: 1)
        criterion = Criterion.create(stage: stage, description: 'Criterion 1', order: 1)
    
        assert criterion
        assert criterion.stage
        assert criterion.description == 'Criterion 1'
        assert criterion.order == 1
    end
    
    # Test you cannot create an invalid criterion
    def test_criterion_order_and_description_are_required
        stage = FactoryBot.create(:stage)
        criterion = Criterion.new(stage: stage)
    
        refute criterion.valid? # "refute": fail if true
        # Validator is included in criterion model (@ doubtfire-api/app/models/feedback/criterion.rb)
        criterion.description = 'Criterion 1'
        refute criterion.valid?
        criterion.order = 1
        assert criterion.valid?
        criterion.description = nil
        refute criterion.valid?
    
        refute criterion.save # fail if criterion is saved
    end
end