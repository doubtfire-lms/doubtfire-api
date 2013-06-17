class UnitRolesController < ApplicationController
  def change_team_allocation
    @unit_role = UnitRole.find(params[:unit_role_id])
    @new_team        = Team.find(params[:new_team_id])

    @unit_role.team = @new_team

    if @unit_role.save
      respond_to do |format|
        format.html { redirect_to @new_team, notice: "Successfully re-allocated into #{@new_team.name}." }
        format.js
      end
      # TODO: Handle else
    end
  end
end
