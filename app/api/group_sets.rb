require 'grape'

module Api
  class GroupSets < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Add a new group set to the given unit"
    params do
      requires :unit_id,                            type: Integer,  :desc => "The unit for the new group set"
      group :group_set do
        requires :name,                             type: String,   :desc => "The name of this group set"
        optional :allow_students_to_create_groups,  type: Boolean,  :desc => "Are students allowed to create groups"
        optional :allow_students_to_manage_groups,  type: Boolean,  :desc => "Are students allowed to manage their group memberships"
        optional :keep_groups_in_same_class,        type: Boolean,  :desc => "Must groups be kept in the one class"
      end
    end
    post '/units/:unit_id/group_sets' do      
      unit = Unit.find(params[:unit_id]) 
      if not authorise? current_user, unit, :update
        error!({"error" => "Not authorised to create a group set for this unit"}, 403)
      end
      
      group_params = ActionController::Parameters.new(params)
        .require(:group_set)
        .permit(
          :name,               
          :allow_students_to_create_groups,        
          :allow_students_to_manage_groups,          
          :keep_groups_in_same_class
        )

      group_set = GroupSet.create!(group_params)
      group_set.unit = unit
      group_set.save!
      group_set
    end
    
    desc "Edits the given group set"
    params do
      requires :id,                     type: Integer,  :desc => "The group set id to edit"
      group :group_set do
        optional :name,                             type: String,   :desc => "The name of this group set"
        optional :allow_students_to_create_groups,  type: Boolean,  :desc => "Are students allowed to create groups"
        optional :allow_students_to_manage_groups,  type: Boolean,  :desc => "Are students allowed to manage their group memberships"
        optional :keep_groups_in_same_class,        type: Boolean,  :desc => "Must groups be kept in the one class"
      end
    end
    put '/units/:unit_id/group_sets/:id' do      
      group_set = GroupSet.find(params[:id])
      unit = Unit.find(params[:unit_id]) 

      if group_set.unit != unit
        error!({"error" => "Unable to locate group set for unit"}, 404)
      end
      
      if not authorise? current_user, unit, :update
        error!({"error" => "Not authorised to update group set for this unit"}, 403)
      end
      
      group_params = ActionController::Parameters.new(params)
        .require(:group_set)
        .permit(
          :name,               
          :allow_students_to_create_groups,        
          :allow_students_to_manage_groups,          
          :keep_groups_in_same_class
        )
      
      group_set.update!(group_params)
      group_set
    end
    
    desc "Delete a group set"
    delete '/units/:unit_id/group_sets/:id' do
      group_set = GroupSet.find(params[:id])
      unit = Unit.find(params[:unit_id]) 

      if group_set.unit != unit
        error!({"error" => "Unable to locate group set for unit"}, 404)
      end
      
      if not authorise? current_user, unit, :update
        error!({"error" => "Not authorised to delete group set for this unit"}, 403)
      end

      group_set.destroy()
    end

    desc "Get the groups in a group set"
    get '/units/:unit_id/group_sets/:id/groups' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:id])

      if not authorise? current_user, group_set, :get_groups, lambda { |role, perm_hash, other| group_set.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to get groups for this unit"}, 403)
      end

      group_set.groups
    end

    desc "Add a new group to the given unit's group_set"
    params do
      requires :unit_id,                            type: Integer,  :desc => "The unit for the new group"
      requires :group_set_id,                       type: Integer,  :desc => "The id of the group set"
      group :group do
        requires :name,                             type: String,   :desc => "The name of this group"
        requires :tutorial_id,                      type: Integer,  :desc => "The id of the tutorial for the group"
      end
    end
    post '/units/:unit_id/group_sets/:group_set_id/groups' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:group_set_id])
      tutorial = unit.tutorials.find(params[:group][:tutorial_id])

      if not authorise? current_user, group_set, :create_group, lambda { |role, perm_hash, other| group_set.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to create a group set for this unit"}, 403)
      end

      group_params = ActionController::Parameters.new(params)
        .require(:group)
        .permit(
          :name
        )

      grp = Group.create(name: group_params[:name], group_set: group_set, tutorial: tutorial)
      grp.save!
      grp
    end
    
    desc "Edits the given group"
    params do
      requires :unit_id,                            type: Integer,  :desc => "The unit for the new group"
      requires :group_set_id,                       type: Integer,  :desc => "The id of the group set"
      requires :group_id,                           type: Integer,  :desc => "The id of the group"
      group :group do
        optional :name,                             type: String,   :desc => "The name of this group set"
        optional :tutorial_id,                      type: Integer,  :desc => "Tutorial of the group"
      end
    end
    put '/units/:unit_id/group_sets/:group_set_id/groups/:group_id' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])

      if not authorise? current_user, grp, :manage_group, lambda { |role, perm_hash, other| grp.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to update this group"}, 403)
      end
      
      group_params = ActionController::Parameters.new(params)
        .require(:group)
        .permit(
          :name,               
          :tutorial_id
        )
      
      grp.update!(group_params)
      grp
    end
    
    desc "Delete a group"
    params do
      requires :unit_id,                            type: Integer,  :desc => "The unit for the new group"
      requires :group_set_id,                       type: Integer,  :desc => "The id of the group set"
      requires :group_id,                           type: Integer,  :desc => "The id of the group"
    end
    delete '/units/:unit_id/group_sets/:group_set_id/groups/:group_id' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])

      if not authorise? current_user, grp, :manage_group, lambda { |role, perm_hash, other| grp.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to delete group set for this unit"}, 403)
      end

      grp.destroy()
      nil
    end

    desc "Get the members of a group"
    get '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:group_set_id])
      grp = group_set.groups.find(params[:group_id])

      if not authorise? current_user, grp, :get_members, lambda { |role, perm_hash, other| grp.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to get groups for this unit"}, 403)
      end

      Thread.current[:user] = current_user
      ActiveModel::ArraySerializer.new(grp.projects, each_serializer: GroupMemberProjectSerializer)
    end

    desc "Add a group member"
    params do
      requires :unit_id,                            type: Integer,  :desc => "The unit for the new group"
      requires :group_set_id,                       type: Integer,  :desc => "The id of the group set"
      requires :group_id,                           type: Integer,  :desc => "The id of the group"
      requires :project_id,                         type: Integer,  :desc => "The project id of the member"
    end
    post '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])
      
      prj = unit.projects.find(params[:project_id])

      if not authorise? current_user, gs, :join_group, lambda { |role, perm_hash, other| gs.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to manage this group"}, 403)
      end

      if not authorise? current_user, prj, :get
        error!({"error" => "Not authorised to manage this student"}, 403)
      end

      gm = grp.add_member(prj)
      Thread.current[:user] = current_user
      GroupMemberProjectSerializer.new(prj)
    end

    desc "Remove a group member"
    params do
      requires :unit_id,                            type: Integer,  :desc => "The unit for the new group"
      requires :group_set_id,                       type: Integer,  :desc => "The id of the group set"
      requires :group_id,                           type: Integer,  :desc => "The id of the group"
      requires :id,                                 type: Integer,  :desc => "The project id of the member"
    end
    delete '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members/:id' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])
      prj = grp.projects.find(params[:id])

      if not authorise? current_user, grp, :manage_group, lambda { |role, perm_hash, other| grp.specific_permission_hash(role, perm_hash, other) }
        error!({"error" => "Not authorised to manage this group"}, 403)
      end

      if not authorise? current_user, prj, :get
        error!({"error" => "Not authorised to manage this student"}, 403)
      end

      grp.remove_member(prj)
      nil
    end
  end
end


