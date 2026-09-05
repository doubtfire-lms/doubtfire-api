require 'fileutils'
require 'digest/sha1'
require 'cgi'
require 'pathname'
require 'securerandom'
require 'set'
require 'uri'
require 'zip'

class UnitContentSite < ApplicationRecord
  include FileHelper

  MAX_ARCHIVE_ENTRIES = 20_000
  MAX_EXTRACTED_BYTES = 2.gigabytes
  MAX_ENTRY_BYTES = 256.megabytes

  belongs_to :unit
  has_many :unit_content_links, dependent: :destroy

  validates :name, :original_filename, :archive_path, presence: true
  validates :name, uniqueness: { scope: :unit_id, case_sensitive: false }
  validates :root_dir, presence: true

  after_destroy :delete_content_files

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
    site.extract_for_serving!
    site
  rescue StandardError
    site&.destroy
    raise
  end

  def replace_upload!(file, root_dir: nil)
    original_archive_path = archive_path
    original_filename_before_replace = original_filename
    original_root_dir = self.root_dir
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
    extract_for_serving!
    FileUtils.rm_f original_archive_path if original_archive_path.present?
    self
  rescue StandardError
    if persisted? && original_archive_path.present?
      update!(
        archive_path: original_archive_path,
        original_filename: original_filename_before_replace,
        root_dir: original_root_dir
      )
    end
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

  def served_dir
    File.join(File.dirname(archive_path), 'served', id.to_s)
  end

  def public_files_path
    "/api/units/#{unit_id}/content/sites/#{id}/files"
  end

  def served_file_path(route)
    relative_route = normalized_content_route(route)
    return nil unless relative_route

    candidates = [relative_route, File.join(relative_route, 'index.html')].uniq
    candidates.each do |candidate|
      path = File.join(served_dir, candidate)
      return path if File.file?(path)
    end

    nil
  end

  def extract_for_serving!
    raise Errno::ENOENT, "Unit content archive not found: #{archive_path}" unless File.file?(archive_path)

    parent_dir = File.dirname(served_dir)
    FileUtils.mkdir_p(parent_dir)
    staging_dir = File.join(parent_dir, ".#{id}-#{SecureRandom.hex(8)}")
    backup_dir = File.join(parent_dir, ".#{id}-backup-#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(staging_dir)

    extract_archive_into!(staging_dir)
    rewrite_extracted_content!(staging_dir)

    FileUtils.mv(served_dir, backup_dir) if File.exist?(served_dir)
    FileUtils.mv(staging_dir, served_dir)
    FileUtils.rm_rf(backup_dir)
    served_dir
  rescue StandardError
    FileUtils.mv(backup_dir, served_dir) if File.exist?(backup_dir) && !File.exist?(served_dir)
    raise
  ensure
    FileUtils.rm_rf(staging_dir) if defined?(staging_dir) && File.exist?(staging_dir)
    FileUtils.rm_rf(backup_dir) if defined?(backup_dir) && File.exist?(backup_dir) && File.exist?(served_dir)
  end

  private

  def extract_archive_into!(destination)
    entry_count = 0
    extracted_bytes = 0
    root_prefix = normalized_root_dir

    Zip::File.open(archive_path) do |zip|
      zip.each do |entry|
        next if entry.directory?
        raise Zip::Error, 'Unit content archive contains a symbolic link' if entry.respond_to?(:symlink?) && entry.symlink?

        entry_count += 1
        raise Zip::Error, 'Unit content archive contains too many files' if entry_count > MAX_ARCHIVE_ENTRIES
        raise Zip::Error, 'Unit content archive contains an oversized file' if entry.size > MAX_ENTRY_BYTES

        extracted_bytes += entry.size
        raise Zip::Error, 'Unit content archive is too large when extracted' if extracted_bytes > MAX_EXTRACTED_BYTES

        entry_path = safe_archive_entry_path(entry.name)
        next unless entry_path
        next unless root_prefix.blank? || entry_path.start_with?("#{root_prefix}/")

        relative_path = root_prefix.blank? ? entry_path : entry_path.delete_prefix("#{root_prefix}/")
        next if relative_path.blank?

        output_path = File.join(destination, relative_path)
        FileUtils.mkdir_p(File.dirname(output_path))
        entry.get_input_stream do |input|
          File.open(output_path, 'wb') { |output| IO.copy_stream(input, output) }
        end
      end
    end
  end

  def safe_archive_entry_path(entry_name)
    normalized = entry_name.to_s.tr('\\', '/')
    parts = normalized.split('/').reject(&:blank?)
    raise Zip::Error, 'Unit content archive contains an unsafe path' if normalized.start_with?('/') || parts.blank?
    raise Zip::Error, 'Unit content archive contains an unsafe path' if parts.any? { |part| ['.', '..'].include?(part) }
    return nil if parts.any? { |part| self.class.ignored_archive_path?(part) }

    parts.join('/')
  end

  def rewrite_extracted_content!(root)
    Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each do |path|
      next unless File.file?(path)

      relative_path = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
      contents = File.binread(path)
      rewritten = rewrite_contents(contents, relative_path)
      File.binwrite(path, rewritten) unless rewritten.equal?(contents) || rewritten == contents
    end
  end

  def rewrite_contents(contents, relative_path)
    extension = File.extname(relative_path).downcase

    case extension
    when '.html', '.htm'
      rewrite_html(contents, relative_path)
    when '.css'
      rewrite_css(contents)
    when '.js', '.mjs'
      rewrite_javascript(contents)
    else
      contents
    end
  rescue Encoding::CompatibilityError, Encoding::InvalidByteSequenceError
    contents
  end

  def rewrite_html(contents, relative_path)
    result = contents.dup.force_encoding(Encoding::UTF_8)
    return contents unless result.valid_encoding?

    base_path = "#{public_files_path}/#{url_path(File.dirname(relative_path))}/".gsub(%r{/+}, '/')
    base_path = "#{public_files_path}/" if File.dirname(relative_path) == '.'
    base_tag = %(<base href="#{CGI.escapeHTML(base_path)}">)

    if result.match?(/<head\b[^>]*>/i)
      result.sub!(/(<head\b[^>]*>)/i, "\\1#{base_tag}")
    else
      result.prepend(base_tag)
    end

    result.gsub!(
      %r{(<(?:iframe|img|link|script|source|video|audio)\b[^>]*?\b(?:href|poster|src)=)(["'])(/(?!/)[^"']*)\2}i
    ) do
      "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{canonical_reference(Regexp.last_match(3))}#{Regexp.last_match(2)}"
    end

    result.gsub!(/\bsrcset=(["'])([^"']+)\1/i) do
      quote = Regexp.last_match(1)
      srcset = Regexp.last_match(2).split(',').map do |item|
        reference, descriptor = item.strip.split(/\s+/, 2)
        reference = canonical_reference(reference) if reference&.start_with?('/') && !reference.start_with?('//')
        [reference, descriptor].compact.join(' ')
      end.join(', ')
      "srcset=#{quote}#{srcset}#{quote}"
    end

    result
  end

  def rewrite_css(contents)
    result = contents.dup.force_encoding(Encoding::UTF_8)
    return contents unless result.valid_encoding?

    result.gsub(%r{url\((["']?)(/(?!/)[^"')]+)\1\)}i) do
      quote = Regexp.last_match(1)
      "url(#{quote}#{canonical_reference(Regexp.last_match(2))}#{quote})"
    end
  end

  def rewrite_javascript(contents)
    result = contents.dup.force_encoding(Encoding::UTF_8)
    return contents unless result.valid_encoding?

    result = result.gsub(
      %r{\b((?:import|export)(?:\s*[^"']*?\s*from\s*)?\s*)(["'])(/(?!/)[^"']+)\2}
    ) do
      "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{canonical_reference(Regexp.last_match(3))}#{Regexp.last_match(2)}"
    end
    result.gsub(%r{\b(import\s*\(\s*)(["'])(/(?!/)[^"']+)\2(\s*\))}) do
      "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{canonical_reference(Regexp.last_match(3))}" \
        "#{Regexp.last_match(2)}#{Regexp.last_match(4)}"
    end
  end

  def canonical_reference(reference)
    path, suffix = reference.split(/(?=[?#])/, 2)
    "#{public_files_path}#{url_path(path)}#{suffix}"
  end

  def url_path(path)
    path.to_s.split('/').map { |part| URI::DEFAULT_PARSER.escape(part) }.join('/')
  end

  def normalized_content_route(route)
    decoded = URI::DEFAULT_PARSER.unescape(route.to_s).tr('\\', '/')
    parts = decoded.split('/').reject(&:blank?)
    return nil if parts.any? { |part| ['.', '..'].include?(part) }

    parts.join('/').presence || 'index.html'
  rescue ArgumentError
    nil
  end

  def archive_entry_name(path)
    relative_path = path.to_s.gsub(%r{\A/+|/+\z}, '')
    return nil if relative_path.blank?

    [normalized_root_dir, relative_path].compact_blank.join('/')
  end

  def normalized_root_dir
    root_dir.to_s.gsub(%r{\A/+|/+\z}, '')
  end

  def delete_content_files
    FileUtils.rm_f archive_path if archive_path.present?
    FileUtils.rm_rf served_dir if id.present?
  end
end
