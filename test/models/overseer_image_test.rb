require "test_helper"

class OverseerImageTest < ActiveSupport::TestCase

  def test_valid
    oi = OverseerImage.create(
      name: 'Image',
      tag: 'image'
    )

    assert oi.valid?
  end

  def test_valid_with_example
    oi = OverseerImage.create(
      name: 'Image',
      tag: 'macite/overseer-dotnet:test'
    )

    assert oi.valid?, oi.errors
  end

  def test_cannot_pull_invalid_tag
    oi = OverseerImage.create(
      name: 'Image',
      tag: 'image & ls'
    )

    refute oi.valid?
    # pull from docker, will refuse as invalid
    refute oi.pull_from_docker
  end

  def test_cannot_inject_code_in_tag
    oi = OverseerImage.create(
      name: 'Image',
      tag: 'image & ls'
    )

    refute oi.valid?

    oi.tag = 'image&ls'
    refute oi.valid?

    oi.tag = 'image|ls'
    refute oi.valid?

    oi.tag = 'image>ls'
    refute oi.valid?

    oi.tag = 'image<ls'
    refute oi.valid?

    oi.tag = 'image($ls)'
    refute oi.valid?

    oi.tag = 'image$ls'
    refute oi.valid?
  end
end
