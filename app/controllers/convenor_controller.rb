class ConvenorController < ApplicationController

  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @convenor_units = UnitRole.includes(:unit)
                      .where(user_id: current_user.id, role_id: Role.where(name: 'Convenor').first)
                      .map{|unit_role| unit_role.unit }
                                                                                
    @active_convenor_units   = @convenor_units.select(&:active?)
    @inactive_convenor_units = @convenor_units - @active_convenor_units
  end

  def load_current_user
    @user = current_user
  end

end