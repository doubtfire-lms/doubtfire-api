require 'grape'
require 'entities/unit_content_link_entity'
require 'entities/unit_content_site_entity'
require 'mime/types'
require 'uri'

class UnitContentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers FileStreamHelper
  helpers MimeCheckHelpers

  helpers do
    def unit_content_link_for_route(unit, content_route)
      normalized_route = "/#{content_route.to_s.gsub(%r{\A/+|/+\z}, '')}"
      normalized_route = '/' if normalized_route.blank?

      unit.unit_content_links
          .where.not(context_type: 'task_definition_resource')
          .find_by(route: normalized_route)
    end

    def authorise_unit_content_management!(unit)
      return if authorise?(current_user, unit, :manage_unit_content) ||
                authorise?(current_user, User, :admin_units)

      error!({ error: 'Not authorised to manage unit content' }, 403)
    end

    def unit_content_reference_url(
      unit_id,
      site_id,
      reference,
      current_path,
      username,
      content_token
    )
      return reference if reference.blank? || reference.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i)

      reference_path = reference.split(/[?#]/, 2).first
      resolved_path =
        if reference_path.start_with?('/')
          reference_path
        else
          File.expand_path(reference_path, "/#{File.dirname(current_path)}")
        end

      query = Rack::Utils.build_query(
        content_route: resolved_path,
        content_site_id: site_id,
        username: username,
        content_token: content_token
      )
      fragment = reference.include?('#') ? "##{reference.split('#', 2).last}" : ''

      "/api/units/#{unit_id}/content?#{query}#{fragment}"
    end

    def rewrite_unit_content_response(
      contents,
      content_type,
      unit_id,
      site_id,
      current_path,
      username,
      content_token
    )
      rewrite_reference = lambda do |reference|
        unit_content_reference_url(
          unit_id,
          site_id,
          reference,
          current_path,
          username,
          content_token
        )
      end

      case content_type
      when 'text/html'
        contents = contents.gsub(
          /(<(?:iframe|img|link|script|source|video|audio)\b[^>]*?\b(?:href|poster|src)=)(["'])([^"']+)\2/i
        ) do
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}" \
            "#{rewrite_reference.call(Regexp.last_match(3))}#{Regexp.last_match(2)}"
        end
        contents.gsub(/\bsrcset=(["'])([^"']+)\1/i) do
          quote = Regexp.last_match(1)
          srcset = Regexp.last_match(2).split(',').map do |entry|
            reference, descriptor = entry.strip.split(/\s+/, 2)
            [rewrite_reference.call(reference), descriptor].compact.join(' ')
          end.join(', ')

          "srcset=#{quote}#{srcset}#{quote}"
        end
      when 'text/css'
        contents.gsub(/url\((["']?)([^"')]+)\1\)/i) do
          quote = Regexp.last_match(1)
          "url(#{quote}#{rewrite_reference.call(Regexp.last_match(2))}#{quote})"
        end
      when 'text/javascript', 'application/javascript'
        contents = contents.gsub(
          /\b((?:import|export)(?:\s*[^"']*?\s*from\s*)?\s*)(["'])([^"']+)\2/
        ) do
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}" \
            "#{rewrite_reference.call(Regexp.last_match(3))}#{Regexp.last_match(2)}"
        end
        contents.gsub(/\b(import\s*\(\s*)(["'])([^"']+)\2(\s*\))/) do
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{rewrite_reference.call(Regexp.last_match(3))}" \
            "#{Regexp.last_match(2)}#{Regexp.last_match(4)}"
        end
      else
        contents
      end
    end
  end

  before do
    if request.path.match?(%r{/units/\d+/content\z})
      authenticated?(:content)
    else
      authenticated?
    end
  end

  desc 'Get a unit content route'
  params do
    optional :content_route, type: String, desc: 'The content route being loaded'
    optional :content_site_id, type: Integer, desc: 'Specific content site to load'
    requires :username, type: String, desc: 'Username associated with the scoped content token'
    requires :content_token, type: String, desc: 'Scoped content authentication token'
  end
  get '/units/:id/content' do
    unit = Unit.find(params[:id])

    unless authorise?(current_user, unit, :get_unit) || authorise?(current_user, User, :admin_units)
      error!({ error: "Couldn't find Unit with id=#{params[:id]}" }, 403)
    end

    link = nil
    site = if params[:content_site_id].present?
             unit.unit_content_sites.find(params[:content_site_id])
           else
             link = unit_content_link_for_route(unit, params[:content_route])
             link&.unit_content_site ||
               unit.unit_content_sites.find_by(is_main: true)
           end

    error!({ error: 'Unit content archive is not configured' }, 404) unless site

    error!({ error: 'Unit content archive is not available' }, 404) unless File.exist?(site.archive_path)

    content_route = URI::DEFAULT_PARSER.unescape(params[:content_route].presence || '/')
    route_parts = content_route.split('/').reject(&:blank?)
    error!({ error: 'Invalid unit content route' }, 422) if route_parts.any? { |part| ['.', '..'].include?(part) }

    root_parts = site.root_dir.to_s.split('/').reject(&:blank?)
    requested_entry_path = (root_parts + route_parts).join('/')
    archive_entry_paths = [
      requested_entry_path,
      (root_parts + route_parts + ['index.html']).join('/')
    ].uniq
    archive_entry = nil
    file_contents = nil

    Zip::File.open(site.archive_path) do |zip_file|
      archive_entry = archive_entry_paths.filter_map { |path| zip_file.find_entry(path) }.find(&:file?)
      file_contents = archive_entry.get_input_stream.read if archive_entry
    end

    error!({ error: "Unit content route '#{content_route}' is not available" }, 404) unless archive_entry

    response_content_type = MIME::Types.type_for(archive_entry.name).first&.content_type
    response_content_type ||= 'application/octet-stream'
    root_prefix = root_parts.join('/')
    current_path = archive_entry.name.delete_prefix("#{root_prefix}/")
    file_contents = rewrite_unit_content_response(
      file_contents,
      response_content_type,
      unit.id,
      site.id,
      current_path,
      params[:username],
      params[:content_token]
    )

    content_type response_content_type
    header['Content-Disposition'] = "inline; filename=#{File.basename(archive_entry.name)}"
    header['X-Content-Site-Id'] = site.id.to_s
    header['X-Content-Route'] = link&.route || content_route
    header['X-Content-Root-Dir'] = site.root_dir
    header['Access-Control-Expose-Headers'] =
      'Content-Disposition,X-Content-Site-Id,X-Content-Route,X-Content-Root-Dir'
    header['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    header['Referrer-Policy'] = 'strict-origin'
    env['api.format'] = :binary

    body file_contents
  rescue Zip::Error
    error!({ error: 'Unit content archive is invalid' }, 422)
  end

  desc 'List unit content sites'
  get '/units/:id/content/sites' do
    unit = Unit.find(params[:id])
    authorise_unit_content_management!(unit)

    present unit.unit_content_sites.order(created_at: :desc),
            with: Entities::UnitContentSiteEntity,
            include_file_paths: true
  end

  desc 'Download a unit content site archive'
  get '/units/:id/content/sites/:site_id/archive' do
    unit = Unit.find(params[:id])
    authorise_unit_content_management!(unit)

    site = unit.unit_content_sites.find(params[:site_id])
    filename = FileHelper.sanitized_filename(site.original_filename)

    content_type 'application/zip'
    header['Content-Disposition'] = "attachment; filename=\"#{filename}\""
    stream_file site.archive_path
  end

  desc 'Upload a unit content site archive'
  params do
    requires :file, type: File, desc: 'The static content site zip'
    optional :name, type: String, desc: 'Display name for the uploaded site'
  end
  post '/units/:id/content/sites' do
    unit = Unit.find(params[:id])
    authorise_unit_content_management!(unit)

    file = params[:file]
    check_mime_against_list! file[:tempfile].path,
                             'zip',
                             ['application/zip',
                              'multipart/x-gzip',
                              'multipart/x-zip',
                              'application/x-gzip',
                              'application/octet-stream']

    site = UnitContentSite.store_upload!(unit, file, name: params[:name])
    present site, with: Entities::UnitContentSiteEntity, include_file_paths: true
  end

  desc 'Delete a unit content site'
  delete '/units/:id/content/sites/:site_id' do
    unit = Unit.find(params[:id])
    authorise_unit_content_management!(unit)

    unit.unit_content_sites.find(params[:site_id]).destroy!
    true
  end

  desc 'Update a unit content site'
  params do
    optional :file, type: File, desc: 'Replacement static content site zip'
    optional :name, type: String, desc: 'Display name for the uploaded site'
    optional :root_dir, type: String, desc: 'Folder within the zip to serve as the site root'
    optional :is_main, type: Boolean, desc: 'Use this as the default site for unit content'
  end
  put '/units/:id/content/sites/:site_id' do
    unit = Unit.find(params[:id])
    authorise_unit_content_management!(unit)

    site = unit.unit_content_sites.find(params[:site_id])
    update_params = declared(params, include_missing: false).slice(:name, :root_dir, :is_main)
    file = params[:file]
    root_dir = update_params[:root_dir]

    if file.present?
      check_mime_against_list! file[:tempfile].path,
                               'zip',
                               ['application/zip',
                                'multipart/x-gzip',
                                'multipart/x-zip',
                                'application/x-gzip',
                                'application/octet-stream']
    end

    root_dir_options =
      file.present? ? UnitContentSite.root_dir_options_for(file[:tempfile].path) : site.root_dir_options

    if root_dir.present? && !root_dir_options.include?(root_dir)
      error!({ error: 'Root directory is not available in this content site archive' }, 422)
    end

    if update_params[:is_main]
      unit.unit_content_sites.where.not(id: site.id).find_each do |content_site|
        content_site.update!(is_main: false)
      end
    end

    if file.present?
      site.replace_upload!(file, root_dir: root_dir)
      update_params.except!(:root_dir)
    end

    site.update!(update_params)
    present site, with: Entities::UnitContentSiteEntity, include_file_paths: true
  end

  desc 'List unit content links'
  get '/units/:id/content/links' do
    unit = Unit.find(params[:id])

    unless authorise?(current_user, unit, :get_unit) || authorise?(current_user, User, :admin_units)
      error!({ error: "Couldn't find Unit with id=#{params[:id]}" }, 403)
    end

    present unit.unit_content_links.includes(:unit_content_site).order(:context_type, :context_key),
            with: Entities::UnitContentLinkEntity
  end

  desc 'Replace unit content links'
  params do
    requires :links, type: Array do
      requires :context_type, type: String
      requires :context_key, type: String
      requires :unit_content_site_id, type: Integer
      optional :route, type: String
    end
  end
  put '/units/:id/content/links' do
    unit = Unit.find(params[:id])
    authorise_unit_content_management!(unit)

    submitted_contexts = params[:links].map do |link_params|
      [link_params[:context_type], link_params[:context_key]]
    end

    unit.unit_content_links
        .where(context_type: %w[grade grade_overview task_definition task_definition_resource])
        .find_each do |link|
      link.destroy! unless submitted_contexts.include?([link.context_type, link.context_key])
    end

    links = params[:links].map do |link_params|
      site = unit.unit_content_sites.find(link_params[:unit_content_site_id])
      link = unit.unit_content_links.find_or_initialize_by(
        context_type: link_params[:context_type],
        context_key: link_params[:context_key]
      )

      link.unit_content_site = site
      link.route = link_params[:route].presence || '/'
      link.save!
      link
    end

    present links, with: Entities::UnitContentLinkEntity
  end
end
