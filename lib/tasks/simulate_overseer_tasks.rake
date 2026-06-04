# lib/tasks/simulate_overseer_tasks.rake
namespace :db do
  desc 'Simulate Overseer Tasks'
  task simulate_overseer_tasks: [:skip_prod, :environment] do
    unit = Unit.first
    user = unit.staff.first.user
    project = unit.projects.first
    task = project.tasks.first
    unit_role = unit.employ_staff(user, Role.convenor)
  end
end
