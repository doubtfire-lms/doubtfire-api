module TutorProjectsHelper
  def unmarked_project_tasks(tutor_project_template)
    projects = Project.where(:project_template_id => tutor_project_template.id)
    projects.map{|project| project.tasks }.flatten.select{|task| task.awaiting_signoff? }
  end
end