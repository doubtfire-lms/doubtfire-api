require 'test_helper'

class UnitContentTaskResourceTest < ActiveSupport::TestCase
  def test_linked_file_takes_priority_over_uploaded_resource_zip
    unit = FactoryBot.create(:unit, with_students: false, stream_count: 0)
    task_definition = FactoryBot.create(
      :task_definition,
      unit: unit,
      abbreviation: 'P1',
      outcome_count: 0
    )

    Tempfile.create(['native-resources', '.zip']) do |native_zip|
      write_zip(native_zip.path, 'native.txt' => 'native resource')
      task_definition.add_task_resources(native_zip.path, copy: true)
    end

    with_content_site(unit, 'dist/P1 Worksheet.docx' => 'linked worksheet') do |site|
      unit.unit_content_links.create!(
        unit_content_site: site,
        context_type: 'task_definition_resource',
        context_key: 'P1',
        route: '/P1 Worksheet.docx'
      )

      task_definition.reload
      resource = task_definition.linked_task_resource

      assert task_definition.has_task_resources?
      assert task_definition.has_uploaded_task_resources?
      assert task_definition.has_task_resource_link?
      assert_not task_definition.task_resource_zip?(resource)
      assert_equal 'P1 Worksheet.docx', resource[:filename]
      assert_equal 'linked worksheet', task_definition.read_file_from_resources(resource[:filename])
    end
  end

  def test_linked_zip_is_used_as_a_task_resource_archive
    unit = FactoryBot.create(:unit, with_students: false, stream_count: 0)
    task_definition = FactoryBot.create(
      :task_definition,
      unit: unit,
      abbreviation: 'P1',
      outcome_count: 0
    )

    Tempfile.create(['linked-resources', '.zip']) do |resource_zip|
      write_zip(resource_zip.path, 'starter/main.py' => 'print("Hello")')

      with_content_site_from_files(unit, 'dist/P1-resources.zip' => resource_zip.path) do |site|
        unit.unit_content_links.create!(
          unit_content_site: site,
          context_type: 'task_definition_resource',
          context_key: 'P1',
          route: '/P1-resources.zip'
        )

        task_definition.reload
        resource = task_definition.linked_task_resource

        assert task_definition.task_resource_zip?(resource)
        assert_equal 'print("Hello")', task_definition.read_file_from_resources('starter/main.py')
      end
    end
  end

  def test_resource_link_requires_an_existing_site_file
    unit = FactoryBot.create(:unit, with_students: false, stream_count: 0)

    with_content_site(unit, 'dist/existing.txt' => 'content') do |site|
      link = unit.unit_content_links.build(
        unit_content_site: site,
        context_type: 'task_definition_resource',
        context_key: 'P1',
        route: '/missing.txt'
      )

      assert_not link.valid?
      assert_includes link.errors[:route], 'must be a file in the selected content site'
    end
  end

  private

  def with_content_site(unit, entries)
    Tempfile.create(['unit-content', '.zip']) do |archive|
      write_zip(archive.path, entries)
      site = unit.unit_content_sites.create!(
        name: 'Content',
        original_filename: 'content.zip',
        archive_path: archive.path,
        root_dir: '/dist'
      )

      yield site
    end
  end

  def with_content_site_from_files(unit, entries)
    Tempfile.create(['unit-content', '.zip']) do |archive|
      Zip::File.open(archive.path, Zip::File::CREATE) do |zip|
        entries.each { |entry_name, source_path| zip.add(entry_name, source_path) }
      end

      site = unit.unit_content_sites.create!(
        name: 'Content',
        original_filename: 'content.zip',
        archive_path: archive.path,
        root_dir: '/dist'
      )

      yield site
    end
  end

  def write_zip(path, entries)
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      entries.each do |entry_name, contents|
        zip.get_output_stream(entry_name) { |stream| stream.write(contents) }
      end
    end
  end
end
