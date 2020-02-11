class DropTablesNotInSchema < ActiveRecord::Migration
  def change
    drop_table :helpdesk_schedules
    drop_table :helpdesk_sessions
    drop_table :helpdesk_tickets
    drop_table :project_convenors
    drop_table :teams
    drop_table :user_roles
  end
end
