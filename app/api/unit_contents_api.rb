require 'grape'
require 'entities/unit_content_link_entity'
require 'entities/unit_content_site_entity'

class UnitContentsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers FileStreamHelper
  helpers MimeCheckHelpers

  helpers do
    def authorise_unit_content_management!(unit)
      return if authorise?(current_user, unit, :manage_unit_content) ||
                authorise?(current_user, User, :admin_units)

      error!({ error: 'Not authorised to manage unit content' }, 403)
    end
  end

  before do
    authenticated?
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

    previous_root_dir = site.root_dir
    site.update!(update_params)
    if file.blank? && update_params.key?(:root_dir)
      begin
        site.extract_for_serving!
      rescue StandardError
        site.update!(root_dir: previous_root_dir)
        raise
      end
    end
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
