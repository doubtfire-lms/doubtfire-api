class OrganizationsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do 
    authenticated?
  end

  # View Enrolled Organizations of a User
  desc 'Find all Organizations of a User'
   get '/organizations/enrolled' do 
   user_orgs = current_user.organizations

   present user_orgs, with: Entities::OrganizationEntity
  end
end


   #View Organization by ID
  desc 'Get organization by ID'
  get '/organizations/:id' do 
    organization = Organization.find(params[:id])
    unless authorise? current_user, organization, :view_members
      error!({error: 'Not Authorized to view the organization'}, 403)
    end
    present organization, with: Entities::OrganizationEntity, includes: [:users]
  end

  #View Members of an Organization
  desc'Get Organization members'
  get '/organizations/:id/members' do
    organization = Organization.find(params[:id])
    unless authorise? current_user, organization, :view_members
        error!({error: 'Not Authorized to view the organization members '}, 403)
    end
    present organization.users, with: Entities::User
  end
   
  #View asll Organizations (Admin)
  desc 'Get all organizations (admin only)'
  get '/organizations' do
    unless authorise? current_user, Organization, :manage_organization
      error!({ error: 'Not authorized to view all organizations' }, 403)
    end
    
    organizations = Organization.all
    present organizations, with: Entities::OrganizationEntity
  end

  #Create New Organization
  desc 'Create a new organization'
  params do 
    requires :organization, type: Hash do 
      requires :name, type: String, desc:'Organization Name'
      optional :description, type:String, desc:'Organization Description'
      optional :email, type: String, desc:'Organization Email'
      optional :is_enabled, type: Boolean, desc:'Organization Status'
    end
  end
  post '/organizations' do 
    unless authorise? current_user, Organization, :manage_organization
      error!({error: 'Not authorized to create an organization'}, 403)
    end
    org_params =  ActionController::Parameters.new(params).require(:organization).permit(:name, :description, :email, :is_enabled)
    # Check if organization with same name already exists
    if Organization.exists?(name: org_params[:name])
      error!({error: 'An organization with this name already exists'}, 422)
    end
    organization = Organization.new(org_params)
    
    if organization.save
      present organization, with: Entities::OrganizationEntity
    else
      error!({error: organization.errors.full_messages.join(', ')}, 422)
    end
  end


  # Update an organization
  desc 'Update an organization'
  params do 
    requires :organization, type: Hash do 
      optional :name, type: String, desc:'Organization Name'
      optional :description, type:String, desc:'Organization Description'
      optional :email, type: String, desc:'Organization Email'
      optional :is_enabled, type: Boolean, desc:'Organization Status'
    end
  end
  put '/organizations/:id' do
    organization = Organization.find(params[:id])
    unless authorise? current_user, organization, :manage_organization
      error!({error: 'Not authorized to update this organization'}, 403)
    end
    
    org_params = ActionController::Parameters.new(params).require(:organization).permit(:name, :description, :email, :is_enabled)
    
    # Check if name is being changed and if it conflicts with existing org
    if org_params[:name].present? && 
       org_params[:name] != organization.name && 
       Organization.where.not(id: params[:id]).exists?(name: org_params[:name])
      error!({error: 'An organization with this name already exists'}, 422)
    end
    
    if organization.update(org_params)
      present organization, with: Entities::OrganizationEntity
    else
      error!({error: organization.errors.full_messages.join(', ')}, 422)
    end
  end
  

  # Delete an organization
  desc 'Delete an organization'
  delete '/organizations/:id' do
    organization = Organization.find(params[:id])
    unless authorise? current_user, organization, :manage_organization
      error!({error: 'Not authorized to delete this organization'}, 403)
    end
    
    # Check if organization has members
    if organization.users.any?
      error!({error: 'Cannot delete organization with members. Remove all members first.'}, 422)
    end
    
    if organization.destroy
      { success: true }
    else
      error!({error: organization.errors.full_messages.join(', ')}, 422)
    end
  end

   #Add Memebr to Organization
  desc 'Add a member to an organization'
   params do
    requires :user_id, type: Integer, desc: 'The ID of the user to add'
   end
   post '/organizations/:id/members' do
    organization = Organization.find(params[:id])
    unless authorise? current_user, organization, :manage_members
        error!({error: 'Not Authorized to add members in this organization'}, 403)
    end
    user = User.find(params[:user_id])
     # Check if user is already a member
    if organization.users.include?(user)
      error!({ error: 'User is already a member of this organization' }, 422)
    end

    organization.users << user 
    present organization, with: Entities::OrganizationEntity
  
  end

   #Organization Switching 
   desc 'Set current organization for user'
   params do
     requires :organization_id, type: Integer, desc: 'The ID of the organization to set as current'
   end
   post '/users/current_organization' do
     organization = Organization.find(params[:organization_id])
     unless current_user.organizations.include?(organization)
       error!({ error: 'User is not a member of this organization' }, 403)
     end
     
     current_user.update(current_organization_id: organization.id)
     present organization, with: Entities::OrganizationEntity
   end

   #Add members by searching their username , name or email
   desc 'Search users to add to organization'
   params do
     requires :query, type: String, desc: 'Search query (username, name, email)'
   end
   get '/organizations/:id/search_users' do
     organization = Organization.find(params[:id])
     unless authorise? current_user, organization, :manage_members
       error!({ error: 'Not authorized to search users for this organization' }, 403)
     end
     
     # Search users not already in the organization
     users = User.where("username LIKE :query OR first_name LIKE :query OR last_name LIKE :query OR email LIKE :query", 
                        query: "%#{params[:query]}%")
                 .where.not(id: organization.user_ids)
                 .limit(20)
     
     present users, with: Entities::User
   end

  desc 'Remove a member from an organization'
  delete '/organizations/:id/members/:user_id' do
  organization = Organization.find(params[:id])
  unless authorise? current_user, organization, :manage_members 
    error!({error: 'Not Authorized to remove members from this organization'}, 403)
  end
  
  user = User.find(params[:user_id])
  user_org = UserOrganization.find_by(user_id: user.id, organization_id: organization.id)
  if user_org
    user_org.destroy
    present organization, with: Entities::OrganizationEntity
    else
     error!({error: 'User is not a member of this organization'}, 404)
    end
  end

  