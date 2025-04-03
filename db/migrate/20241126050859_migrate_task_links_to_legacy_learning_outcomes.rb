class MigrateTaskLinksToLegacyLearningOutcomes < ActiveRecord::Migration[7.1]
  def up
    sql = "SELECT `learning_outcome_task_links`.* FROM `learning_outcome_task_links` GROUP BY `learning_outcome_task_links`.`task_definition_id`"
    result = ActiveRecord::Base.connection.exec_query(sql)
    grouped_links = result.group_by{|r| r['task_definition_id']}

    grouped_links.each do |task_definition_id, links|
      task_definition = TaskDefinition.find(task_definition_id)

      linked_outcome_ids = links.map{|r| r['learning_outcome_id']}.uniq

      next if linked_outcome_ids.empty?

      legacy_learning_outcome = LearningOutcome.create!(
        context_id: task_definition.id,
        context_type: 'TaskDefinition',
        abbreviation: 'TLO1',
        short_description: 'Demonstrate these learning outcomes (legacy)',
        full_outcome_description: 'Demonstrate engagement with the following unit learning outcomes (legacy)'
      )

      linked_outcome_ids.each do |linked_outcome_id|
        LearningOutcomeLink.create!(
          source_id: legacy_learning_outcome.id,
          target_id: linked_outcome_id
        )
      end
    end
  end

  def down
    legacy_outcomes = LearningOutcome.where(
      context_type: 'TaskDefinition',
      abbreviation: 'TLO1',
      short_description: 'Demonstrate these learning outcomes (legacy)',
      full_outcome_description: 'Demonstrate engagement with the following unit learning outcomes (legacy)'
    )

    legacy_outcomes.each do |legacy_outcome|
      LearningOutcomeLink.where(source_id: legacy_outcome.id).destroy_all
      legacy_outcome.destroy
    end
  end
end
