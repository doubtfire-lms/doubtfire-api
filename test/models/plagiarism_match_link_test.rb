require "test_helper"

class PlagiarismMatchLinkTest < ActiveSupport::TestCase
  def test_kind_string
    task = FactoryBot.create(:task)

    pml = PlagiarismMatchLink.create(
      task: task,
      other_task: task,
      kind: 'tii',
      pct: 10
    )

    assert pml.valid?, pml.errors.full_messages

    pml.kind = 'tii not!'
    refute pml.valid?, pml.errors.full_messages

    pml.kind = 'not tii'
    refute pml.valid?, pml.errors.full_messages

    pml.kind = 'moss'
    assert pml.valid?, pml.errors.full_messages

    pml.kind = 'moss not!'
    refute pml.valid?, pml.errors.full_messages

    pml.kind = 'not moss'
    refute pml.valid?, pml.errors.full_messages

  ensure
    task.project.unit.destroy
  end

  # Test that when you create a plagiarism match link, that a moss test needs the other task
  def test_other_details
    task = FactoryBot.create(:task)

    pml = PlagiarismMatchLink.create(
      task: task,
      kind: 'moss',
      pct: 10
    )

    refute pml.valid?, pml.errors.full_messages

    pml.other_task = task
    assert pml.valid?, pml.errors.full_messages

  ensure
    task.project.unit.destroy
  end

  # Test to ensure that pct must be between 0 and 100
  def test_pml_pct
    task = FactoryBot.create(:task)

    pml = PlagiarismMatchLink.create(
      task: task,
      kind: 'tii',
      pct: 10
    )

    assert pml.valid?, pml.errors.full_messages

    pml.pct = -1
    refute pml.valid?
    pml.pct = 101
    refute pml.valid?

    pml.pct = 0
    assert pml.valid?, pml.errors.full_messages
    pml.pct = 100
    assert pml.valid?, pml.errors.full_messages

  ensure
    task.project.unit.destroy
  end
end
