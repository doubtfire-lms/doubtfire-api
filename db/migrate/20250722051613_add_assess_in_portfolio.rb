class AddAssessInPortfolio < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :assess_in_portfolio_only, :boolean, null: false, default: false

    add_column :units, :mark_late_submissions_as_assess_in_portfolio, :boolean, null: false, default: false

    if TaskStatus.where(name: 'Assess in Portfolio').count < 1
      TaskStatus.create name: "Assess in Portfolio", description: "This task will not be signed off as complete by your tutor, and will be marked directly in your portfolio."
    end
  end
end
