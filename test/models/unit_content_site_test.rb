require 'test_helper'

class UnitContentSiteTest < ActiveSupport::TestCase
  def test_content_version_includes_the_archive_and_rewrite_version
    Tempfile.create(['unit-content-version', '.zip']) do |archive|
      write_zip(archive.path, 'index.html' => '<html><head></head><body>Content</body></html>')

      site = create_site(archive.path)

      archive_hash = Digest::SHA256.file(archive.path).hexdigest
      expected_version = Digest::SHA256.hexdigest(
        "#{UnitContentSite::CONTENT_REWRITE_VERSION}:#{archive_hash}:"
      )

      assert_equal expected_version, site.content_version
    end
  end

  def test_root_change_updates_content_version
    Tempfile.create(['unit-content-version', '.zip']) do |archive|
      write_zip(
        archive.path,
        'site/index.html' => '<html><head></head><body>Content</body></html>'
      )

      site = create_site(archive.path)
      original_version = site.content_version
      site.update!(root_dir: '/site')

      assert_not_equal original_version, site.content_version
    end
  end

  def test_extraction_rewrites_root_relative_links_to_versioned_site_urls
    Tempfile.create(['unit-content-version', '.zip']) do |archive|
      write_zip(
        archive.path,
        'index.html' => <<~HTML,
          <html><head></head><body>
            <a href="/Course Worksheet.docx">Download</a>
          </body></html>
        HTML
        'Course Worksheet.docx' => 'worksheet'
      )

      site = create_site(archive.path)
      site.extract_for_serving!

      rewritten_html = File.read(File.join(site.served_dir, 'index.html'))
      assert_includes rewritten_html, "/files/v/#{site.content_version}/"
      assert_includes rewritten_html,
                      "/files/v/#{site.content_version}/Course%20Worksheet.docx"
    end
  end

  def test_replacing_an_archive_updates_the_content_version_and_served_files
    Dir.mktmpdir('unit-content-storage') do |storage_dir|
      Tempfile.create(['original-content', '.zip']) do |original_archive|
        Tempfile.create(['replacement-content', '.zip']) do |replacement_archive|
          write_zip(original_archive.path, 'content.txt' => 'Original content')
          write_zip(replacement_archive.path, 'content.txt' => 'Replacement content')

          unit = FactoryBot.create(:unit, with_students: false, stream_count: 0)
          site = nil

          UnitContentSite.stub(:archive_dir_for, storage_dir) do
            site = UnitContentSite.store_upload!(
              unit,
              { filename: 'content.zip', tempfile: original_archive }
            )
            original_version = site.content_version

            site.replace_upload!(
              { filename: 'content.zip', tempfile: replacement_archive }
            )

            assert_not_equal original_version, site.content_version
            assert_equal 'Replacement content', File.read(File.join(site.served_dir, 'content.txt'))
          end
        ensure
          site&.destroy!
        end
      end
    end
  end

  private

  def create_site(archive_path)
    unit = FactoryBot.create(:unit, with_students: false, stream_count: 0)
    unit.unit_content_sites.create!(
      name: 'Content',
      original_filename: 'content.zip',
      archive_path: archive_path,
      root_dir: '/'
    )
  end

  def write_zip(path, entries)
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      entries.each do |entry_name, contents|
        zip.get_output_stream(entry_name) { |stream| stream.write(contents) }
      end
    end
  end
end
