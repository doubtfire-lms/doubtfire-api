# freeze_string_literal: true

# Provides moss and tii similarity features in task definitions
module TaskDefinitionSimilarityModule
  def moss_similarities?
    MossTaskSimilarity.joins(:task).where('tasks.task_definition_id' => id).count > 0
  end

  def clear_related_plagiarism
    # delete old plagiarism links
    logger.info "Deleting old links for task definition #{id} - #{abbreviation}"
    MossTaskSimilarity.joins(:task).where('tasks.task_definition_id' => id).find_each do |plnk|
      pair = MossTaskSimilarity.find_by(id: plnk.id)
      pair.destroy! if pair.present?
    end
  end
end
