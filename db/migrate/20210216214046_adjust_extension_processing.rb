class AdjustExtensionProcessing < ActiveRecord::Migration
  def change
    add_column :units, :allow_student_extension_requests, :boolean, null: false, default: true
    add_column :units, :extension_weeks_on_resubmit_request, :integer, null: false, default: 1
  end
end
