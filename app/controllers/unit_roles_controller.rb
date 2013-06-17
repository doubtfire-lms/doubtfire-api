class UnitRolesController < ApplicationController
  def change_tutorial_allocation
    @unit_role = UnitRole.find(params[:unit_role_id])
    @new_tutorial        = Tutorial.find(params[:new_tutorial_id])

    @unit_role.tutorial = @new_tutorial

    if @unit_role.save
      respond_to do |format|
        format.html { redirect_to @new_tutorial, notice: "Successfully re-allocated into #{@new_tutorial.name}." }
        format.js
      end
      # TODO: Handle else
    end
  end
end
