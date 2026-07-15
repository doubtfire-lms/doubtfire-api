require 'fileutils'
require 'digest/sha1'
require 'securerandom'
require 'set'
require 'zip'

class UnitContentSite < ApplicationRecord
  include FileHelper

  belongs_to :unit
  has_many :unit_content_links, dependent: :destroy

  validates :name, :original_filename, :archive_path, presence: true
  validates :name, uniqueness: { scope: :unit_id, case_sensitive: false }
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

  def file_paths
    root_prefix = normalized_root_dir

    self.class.archive_entries_for(archive_path).filter_map do |entry|
      parts = entry.split('/').reject(&:blank?)
      next if parts.any? { |part| self.class.ignored_archive_path?(part) }
      next unless root_prefix.blank? || entry.start_with?("#{root_prefix}/")

      relative_path = root_prefix.blank? ? entry : entry.delete_prefix("#{root_prefix}/")
      "/#{relative_path}" if relative_path.present?
    end.sort
  rescue Zip::Error, Errno::ENOENT
    []
  end

  def file?(path)
    entry_name = archive_entry_name(path)
    return false if entry_name.blank? || !File.exist?(archive_path)

    Zip::File.open(archive_path) do |zip|
      entry = zip.find_entry(entry_name)
      entry.present? && entry.file?
    end
  rescue Zip::Error
    false
  end

  def extract_file(path)
    entry_name = archive_entry_name(path)
    return nil if entry_name.blank? || !File.exist?(archive_path)

    Zip::File.open(archive_path) do |zip|
      entry = zip.find_entry(entry_name)
      return nil unless entry&.file?

      filename = File.basename(entry.name)
      cache_key = Digest::SHA1.hexdigest("#{archive_path}:#{entry.name}:#{updated_at.to_f}")
      extracted_path = FileHelper.tmp_file(
        "unit-content-#{id}-#{cache_key}-#{FileHelper.sanitized_filename(filename)}"
      )

      unless File.exist?(extracted_path) && File.size(extracted_path) == entry.size
        temporary_path = "#{extracted_path}.#{SecureRandom.hex(6)}.tmp"
        entry.extract(temporary_path) { true }
        FileUtils.mv(temporary_path, extracted_path)
      end

      { path: extracted_path, filename: filename }
    ensure
      FileUtils.rm_f(temporary_path) if defined?(temporary_path) && temporary_path.present?
    end
  rescue Zip::Error
    nil
  end

  private

  def archive_entry_name(path)
    relative_path = path.to_s.gsub(%r{\A/+|/+\z}, '')
    return nil if relative_path.blank?

    [normalized_root_dir, relative_path].compact_blank.join('/')
  end

  def normalized_root_dir
    root_dir.to_s.gsub(%r{\A/+|/+\z}, '')
  end

  def delete_archive
    FileUtils.rm_f archive_path if archive_path.present?
  end
end
