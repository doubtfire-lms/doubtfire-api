class TeamMembershipsController < ApplicationController
  def change_team_allocation
    @team_membership = TeamMembership.find(params[:team_membership_id])
    @new_team        = Team.find(params[:new_team_id])

    @team_membership.team = @new_team

    if @team_membership.save
      respond_to do |format|
        format.html { redirect_to @new_team, notice: "Successfully re-allocated into #{@new_team.name}." }
        format.js
      end
      # TODO: Handle else
    end
  end
end