require 'grape'

#
# Allow GroupSets to be managed via the API
#
class GroupSetsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers
  helpers LogHelper

  before do
    authenticated?
  end

  # ------------------------------------------------------------------------
  # Group Sets
  # ------------------------------------------------------------------------

  desc 'Add a new group set to the given unit'
  params do
    requires :unit_id, type: Integer, desc: 'The unit for the new group set'
    requires :group_set, type: Hash do
      requires :name,                             type: String,   desc: 'The name of this group set'
      optional :allow_students_to_create_groups,  type: Boolean,  desc: 'Are students allowed to create groups'
      optional :allow_students_to_manage_groups,  type: Boolean,  desc: 'Are students allowed to manage their group memberships'
      optional :keep_groups_in_same_class,        type: Boolean,  desc: 'Must groups be kept in the one class'
      optional :capacity,                         type: Integer,  desc: 'Capacity for each group'
    end
  end
  post '/units/:unit_id/group_sets' do
    unit = Unit.find(params[:unit_id])
    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to create a group set for this unit' }, 403)
    end

    logger.info "Create group set: #{current_user.username} in #{unit.code} from #{request.ip}"

    group_params = ActionController::Parameters.new(params)
                                               .require(:group_set)
                                               .permit(
                                                 :name,
                                                 :allow_students_to_create_groups,
                                                 :allow_students_to_manage_groups,
                                                 :keep_groups_in_same_class,
                                                 :capacity
                                               )

    group_set = GroupSet.create(group_params)
    group_set.unit = unit
    group_set.save!
    present group_set, with: Entities::GroupSetEntity
  end

  desc 'Edits the given group set'
  params do
    requires :id, type: Integer, desc: 'The group set id to edit'
    requires :group_set, type: Hash do
      optional :name,                             type: String,   desc: 'The name of this group set'
      optional :allow_students_to_create_groups,  type: Boolean,  desc: 'Are students allowed to create groups'
      optional :allow_students_to_manage_groups,  type: Boolean,  desc: 'Are students allowed to manage their group memberships'
      optional :keep_groups_in_same_class,        type: Boolean,  desc: 'Must groups be kept in the one class'
      optional :capacity,                         type: Integer,  desc: 'Capacity for each group'
      optional :locked,                           type: Boolean,  desc: 'Is this group set locked'
    end
  end
  put '/units/:unit_id/group_sets/:id' do
    group_set = GroupSet.find(params[:id])
    unit = Unit.find(params[:unit_id])

    logger.info "Edit group set: #{current_user.username} in #{unit.code} from #{request.ip}"

    if group_set.unit != unit
      error!({ error: 'Unable to locate group set for unit' }, 404)
    end

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update group set for this unit' }, 403)
    end

    group_params = ActionController::Parameters.new(params)
                                               .require(:group_set)
                                               .permit(
                                                 :name,
                                                 :allow_students_to_create_groups,
                                                 :allow_students_to_manage_groups,
                                                 :keep_groups_in_same_class,
                                                 :capacity,
                                                 :locked,
                                               )

    group_set.update!(group_params)
    present group_set, with: Entities::GroupSetEntity
  end

  desc 'Delete a group set'
  delete '/units/:unit_id/group_sets/:id' do
    group_set = GroupSet.find(params[:id])
    unit = Unit.find(params[:unit_id])

    logger.info "Delete group set: #{current_user.username} in #{unit.code} from #{request.ip}"

    if group_set.unit != unit
      error!({ error: 'Unable to locate group set for unit' }, 404)
    end

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to delete group set for this unit' }, 403)
    end

    error!(error: group_set.errors[:base].last) unless group_set.destroy
    present true, with: Grape::Presenters::Presenter
  end

  # ------------------------------------------------------------------------
  # Groups
  # ------------------------------------------------------------------------

  desc 'Get the groups in a group set'
  get '/units/:unit_id/group_sets/:id/groups' do
    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:id])

    unless authorise? current_user, group_set, :get_groups, ->(role, perm_hash, other) { group_set.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to get groups for this unit' }, 403)
    end

    result = group_set
             .groups
             .joins('LEFT OUTER JOIN group_memberships ON group_memberships.group_id = groups.id AND group_memberships.active = TRUE')
             .group(
               'groups.id',
               'groups.name',
               'groups.tutorial_id',
               'groups.group_set_id',
               'groups.capacity_adjustment',
               'groups.locked',
             )
             .select(
               'groups.id as id',
               'groups.name as name',
               'groups.tutorial_id as tutorial_id',
               'groups.group_set_id as group_set_id',
               'groups.capacity_adjustment as capacity_adjustment',
               'groups.locked as locked',
               'COUNT(group_memberships.id) as student_count'
             )
    present result, with: Grape::Presenters::Presenter
  end

  desc 'Download a CSV of groups and their students in a group set'
  get '/units/:unit_id/group_sets/:group_set_id/groups/student_csv' do
    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:group_set_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to download csv of groups for this unit' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-#{group_set.name}-student-groups.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    unit.export_student_groups_to_csv(group_set)
  end

  desc 'Download a CSV of groups in a group set'
  get '/units/:unit_id/group_sets/:group_set_id/groups/csv' do
    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:group_set_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to download csv of groups for this unit' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-#{group_set.name}-groups.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    unit.export_groups_to_csv(group_set)
  end

  desc "Add a new group to the given unit's group_set"
  params do
    requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
    requires :group, type: Hash do
      optional :name,                             type: String,   desc: 'The name of this group'
      requires :tutorial_id,                      type: Integer,  desc: 'The id of the tutorial for the group'
      optional :capacity_adjustment,              type: Integer,  desc: 'How capacity for group is adjusted', default: 0
    end
  end
  post '/units/:unit_id/group_sets/:group_set_id/groups' do
    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:group_set_id])
    tutorial = unit.tutorials.find(params[:group][:tutorial_id])

    unless authorise? current_user, group_set, :create_group, ->(role, perm_hash, other) { group_set.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to create a group set for this unit' }, 403)
    end

    group_params = ActionController::Parameters.new(params)
                                               .require(:group)
                                               .permit(
                                                 :name,
                                                 :capacity_adjustment
                                               )

    # Group with the same name
    unless group_set.groups.where(name: group_params[:name]).empty?
      error!({ error: "This group name is not unique to the #{group_set.name} group set." }, 403)
    end

    # Now check if they are a student...
    project = nil
    if unit.role_for(current_user) == Role.student
      project = unit.active_projects.find_by(user_id: current_user.id)
      # They cannot already be in a group for this group set
      error!({ error: "You are already in a group for #{group_set.name}" }, 403) unless project.group_for_groupset(group_set).nil?
    end

    num = group_set.groups.count + 1
    while group_params[:name].nil? || group_params[:name].empty? || group_set.groups.where(name: group_params[:name]).count > 0
      group_params[:name] = "Group #{num}"
      num += 1
    end
    grp = Group.create(name: group_params[:name], group_set: group_set, tutorial: tutorial)
    grp.save!

    # If they are a student, then add them to the group they created
    if project.present?
      grp.add_member(project)
    end

    present grp, with: Entities::GroupEntity
  end

  desc 'Upload a CSV for groups in a group set'
  params do
    requires :unit_id,      type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id, type: Integer,  desc: 'The id of the group set'
    requires :file,         type: File, desc: 'CSV upload file.'
  end
  post '/units/:unit_id/group_sets/:group_set_id/groups/csv' do
    # check mime is correct before uploading
    ensure_csv!(params[:file][:tempfile])

    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:group_set_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to upload csv of groups for this unit' }, 403)
    end

    present unit.import_groups_from_csv(group_set, params[:file][:tempfile]), with: Grape::Presenters::Presenter
  end

  desc 'Upload a CSV for students in groups in a group set'
  params do
    requires :unit_id,      type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id, type: Integer,  desc: 'The id of the group set'
    requires :file,         type: File, desc: 'CSV upload file.'
  end
  post '/units/:unit_id/group_sets/:group_set_id/groups/student_csv' do
    # check mime is correct before uploading
    ensure_csv!(params[:file][:tempfile])

    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:group_set_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to upload csv of groups for this unit' }, 403)
    end

    present unit.import_student_groups_from_csv(group_set, params[:file][:tempfile]), with: Grape::Presenters::Presenter
  end

  desc 'Edits the given group'
  params do
    requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
    requires :group_id,                           type: Integer,  desc: 'The id of the group'
    requires :group, type: Hash do
      optional :name,                             type: String,   desc: 'The name of this group set'
      optional :tutorial_id,                      type: Integer,  desc: 'Tutorial of the group'
      optional :capacity_adjustment,              type: Integer,  desc: 'How capacity for group is adjusted'
      optional :locked,                           type: Boolean,  desc: 'Is the group locked'
    end
  end
  put '/units/:unit_id/group_sets/:group_set_id/groups/:group_id' do
    unit = Unit.find(params[:unit_id])
    gs = unit.group_sets.find(params[:group_set_id])
    grp = gs.groups.find(params[:group_id])

    unless authorise? current_user, grp, :manage_group, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to update this group' }, 403)
    end

    group_params = ActionController::Parameters.new(params)
                                               .require(:group)
                                               .permit(
                                                 :name,
                                                 :tutorial_id,
                                                 :capacity_adjustment,
                                                 :locked,
                                               )

    # Allow locking only if the current user has permission to do so
    if params[:group][:locked].present? && params[:group][:locked] != grp.locked
      unless authorise? current_user, grp, :lock_group
        error!({ error: "Not authorised to #{grp.locked ? 'unlock' : 'lock'} this group" }, 403)
      end
    end

    # Switching tutorials will violate any existing group members
    if params[:group][:tutorial_id].present? && params[:group][:tutorial_id] != grp.tutorial_id
      if authorise? current_user, grp, :move_tutorial
        tutorial = unit.tutorials.find_by(id: params[:group][:tutorial_id])
        begin
          grp.switch_to_tutorial tutorial
        rescue StandardError => e
          error!({ error: e.message }, 403)
        end
      else
        error!({ error: 'You are not authorised to change the tutorial of this group' }, 403)
      end
    end

    if params[:group][:capacity_adjustment].present? && params[:group][:capacity_adjustment] != grp.capacity_adjustment
      if authorise? current_user, grp, :move_tutorial
        group_params[:capacity_adjustment] = params[:group][:capacity_adjustment]
      else
        error!({ error: 'You are not authorised to change the capacity of this group' }, 403)
      end
    end

    grp.update!(group_params)
    present grp, with: Entities::GroupEntity
  end

  desc 'Delete a group'
  params do
    requires :unit_id,      type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id, type: Integer,  desc: 'The id of the group set'
    requires :group_id,     type: Integer,  desc: 'The id of the group'
  end
  delete '/units/:unit_id/group_sets/:group_set_id/groups/:group_id' do
    unit = Unit.find(params[:unit_id])
    gs = unit.group_sets.find(params[:group_set_id])
    grp = gs.groups.find(params[:group_id])

    unless authorise? current_user, grp, :manage_group, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to delete group set for this unit' }, 403)
    end

    unless unit.tutors.include? current_user
      # check that they are the only member of the group, or the group is empty
      error!({ error: 'You cannot delete a group with members' }, 403) unless grp.projects.count <= 1
      error!({ error: 'You cannot delete this group' }, 403) unless grp.projects.count.zero? || grp.projects.first.student == current_user
    end

    grp.destroy!
  end

  desc 'Get the members of a group'
  get '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members' do
    unit = Unit.find(params[:unit_id])
    group_set = unit.group_sets.find(params[:group_set_id])
    grp = group_set.groups.find(params[:group_id])

    unless authorise? current_user, grp, :get_members, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to get groups for this unit' }, 403)
    end

    present grp.projects, with: Entities::ProjectEntity, only: [:student, :id, :target_grade], user: current_user
  end

  desc 'Add a group member'
  params do
    requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
    requires :group_id,                           type: Integer,  desc: 'The id of the group'
    requires :project_id,                         type: Integer,  desc: 'The project id of the member'
  end
  post '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members/:project_id' do
    unit = Unit.find(params[:unit_id])
    gs = unit.group_sets.find(params[:group_set_id])
    grp = gs.groups.find(params[:group_id])

    prj = unit.active_projects.find(params[:project_id])

    unless authorise? current_user, gs, :join_group, ->(role, perm_hash, other) { gs.specific_permission_hash(role, perm_hash, other) }
      if gs.locked
        error!({ error: 'All of these groups are now locked' }, 403)
      else
        error!({ error: 'Not authorised to manage this group' }, 403)
      end
    end

    unless authorise? current_user, prj, :get
      error!({ error: 'Not authorised to manage this student' }, 403)
    end

    if gs.keep_groups_in_same_class && !prj.enrolled_in?(grp.tutorial)
      error!({ error: "Students from the tutorial '#{grp.tutorial.abbreviation}' can only be added to this group." }, 403)
    end

    if grp.active_group_members.find_by(project: prj, active: true)
      error!({ error: "#{prj.student.name} is already a member of this group" }, 403)
    end

    if grp.locked
      error!({ error: 'Group is locked, no additional members can be added' }, 403)
    end

    if grp.at_capacity? && !authorise?(current_user, grp, :can_exceed_capacity)
      error!({ error: 'Group is at capacity, no additional members can be added' }, 403)
    end

    gm = grp.add_member(prj)

    present prj, with: Entities::ProjectEntity, only: [:student_username, :id, :student_first_name, :student_last_name, :student_nickname, :target_grade], user: current_user
  end

  desc 'Remove a group member'
  params do
    requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
    requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
    requires :group_id,                           type: Integer,  desc: 'The id of the group'
    requires :id,                                 type: Integer,  desc: 'The project id of the member'
  end
  delete '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members/:id' do
    unit = Unit.find(params[:unit_id])
    gs = unit.group_sets.find(params[:group_set_id])
    grp = gs.groups.find(params[:group_id])
    prj = grp.projects.find(params[:id])

    unless authorise? current_user, grp, :manage_group, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
      if grp.locked || gs.locked
        error!({ error: 'This group is locked' }, 403)
      else
        error!({ error: 'Not authorised to manage this group' }, 403)
      end
    end

    unless authorise? current_user, prj, :get
      error!({ error: 'Not authorised to manage this student' }, 403)
    end

    if grp.active_group_members.find_by(project: prj).nil?
      error!({ error: "#{prj.student.name} is not a member of this group" }, 403)
    end

    grp.remove_member(prj)
    true
  end
end
