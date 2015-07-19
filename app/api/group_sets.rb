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
      group_set = GroupSet.find(params[:id])
      unit = Unit.find(params[:unit_id]) 

      if not authorise? current_user, unit, :get_unit
        error!({"error" => "Not authorised to get groups for this unit"}, 403)
      end

      group_set.groups
    end
  end
end


