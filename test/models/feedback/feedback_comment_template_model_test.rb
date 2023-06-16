require 'test_helper'

#
# Contains tests for FeedbackCommentTemplate model objects - not accessed via API
# 
class FeedbackCommentTemplateModelTest < ActiveSupport::TestCase

    # Setup objects for testing
    def setup
        DatabaseCleaner.start
        task_status = TaskStatus.new
        @criterion_option = CriterionOption.create(task_status: task_status)
    end

    # Test you can create a valid feedback comment template
    def test_valid_feedback_comment_template_creation
        feedback_comment_template = FeedbackCommentTemplate.create(criterion_option: @criterion_option, comment_text_situation: 'This is the situation')

        assert feedback_comment_template.valid?
        
        assert feedback_comment_template.criterion_option == @criterion_option
        assert feedback_comment_template.comment_text_situation == 'This is the situation'
    end

    # Test you cannot create an invalid feedback comment template
    def test_invalid_feedback_comment_template_creation
        feedback_comment_template = FeedbackCommentTemplate.new
        refute feedback_comment_template.valid?

        feedback_comment_template.comment_text_situation = 'This is a comment'
        refute feedback_comment_template.valid?

        feedback_comment_template.criterion_option = @criterion_option
        assert feedback_comment_template.valid?

        feedback_comment_template.comment_text_situation = nil
        refute feedback_comment_template.valid?

        refute feedback_comment_template.save
    end
end
