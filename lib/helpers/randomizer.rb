class Randomizer
  #
  # Randomly returns a new model (e.g., random_record_for_model(Project))
  #
  def self.random_record_for_model(model)
    throw 'Must provide a model' unless model.is_a? Class
    id = model.all.pluck(:id).sample
    model.find(id)
  end

  #
  # Randomly returns a new task for the given project
  #
  def self.random_task_for_project(project)
    task_def = random_task_def_for_project(project)
    project.task_for_task_definition(task_def)
  end

  #
  # Randomly returns a new task definition for the given project
  #
  def self.random_task_def_for_project(project)
    project.unit.task_definitions.sample
  end
end
