class AddEnforceFeedbackBeforeDiscussedInClass < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :enforce_feedback_before_discussed_in_class, :boolean, null: false, default: false
  end
end
