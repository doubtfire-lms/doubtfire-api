require 'fileutils'
require 'securerandom'
require 'set'
require 'zip'

class UnitContentSite < ApplicationRecord
  include FileHelper

  belongs_to :unit
  has_many :unit_content_links, dependent: :destroy

  validates :name, :original_filename, :archive_path, presence: true
  validates :root_dir, presence: true

  after_destroy :delete_archive

  def self.archive_dir_for(unit)
    File.join(FileHelper.unit_dir(unit), 'content_sites')
  end

  def self.store_upload!(unit, file, name: nil)
    original_filename = file[:filename] || file[:name] || 'content.zip'
    site_name = name.presence || File.basename(original_filename, '.*')
    archive_dir = archive_dir_for(unit)
    FileUtils.mkdir_p archive_dir

    site = unit.unit_content_sites.create!(
      name: site_name,
      original_filename: original_filename,
      root_dir: '/',
      is_main: unit.unit_content_sites.none?,
      archive_path: File.join(
        archive_dir,
        "#{SecureRandom.hex(8)}-#{FileHelper.sanitized_filename(original_filename)}"
      )
    )

    FileUtils.cp file[:tempfile].path, site.archive_path
    site
  end

  def replace_upload!(file, root_dir: nil)
    original_archive_path = archive_path
    replacement_original_filename = file[:filename] || file[:name] || original_filename
    replacement_archive_path = File.join(
      self.class.archive_dir_for(unit),
      "#{SecureRandom.hex(8)}-#{FileHelper.sanitized_filename(replacement_original_filename)}"
    )

    FileUtils.cp file[:tempfile].path, replacement_archive_path
    replacement_root_options = self.class.root_dir_options_for(replacement_archive_path)
    replacement_root_dir =
      root_dir.presence ||
      (replacement_root_options.include?(self.root_dir) ? self.root_dir : '/')

    update!(
      original_filename: replacement_original_filename,
      archive_path: replacement_archive_path,
      root_dir: replacement_root_dir
    )
    FileUtils.rm_f original_archive_path if original_archive_path.present?
    self
  rescue StandardError
    FileUtils.rm_f replacement_archive_path if replacement_archive_path.present?
    raise
  end

  def self.root_dir_options_for(archive_path)
    root_dir_options_from_entries(archive_entries_for(archive_path))
  rescue Zip::Error
    ['/']
  end

  def self.archive_entries_for(archive_path)
    entries = []

    Zip::File.open(archive_path) do |zip|
      zip.each do |entry|
        entries << entry.name unless entry.directory?
      end
    end

    entries
  end

  def self.root_dir_options_from_entries(entries)
    dirs = entries.each_with_object(Set.new(['/'])) do |entry, paths|
      parts = entry.split('/').reject(&:blank?)
      next if parts.any? { |part| ignored_archive_path?(part) }

      parts[0...-1].each_index do |index|
        paths << "/#{parts[0..index].join('/')}"
      end
    end

    dirs.to_a.sort
  end

  def self.ignored_archive_path?(path)
    path.start_with?('__MACOSX') || path == '.DS_Store' || path.start_with?('._')
  end

  def root_dir_options
    self.class.root_dir_options_for(archive_path)
  end

  private

  def delete_archive
    FileUtils.rm_f archive_path if archive_path.present?
  end
end
