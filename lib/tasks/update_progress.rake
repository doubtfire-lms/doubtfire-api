namespace :submission do
  desc 'Update current projects task stats'

  def logger
    Rails.logger
  end

  task update_progress: :environment do
    logger.info 'Starting update progress stats'

    Project.includes(:tasks).includes(:unit).load.where('projects.enrolled = true and units.end_date > :now', now: Time.zone.now).references(:unit).each(&:calc_task_stats)

    logger.info 'Update progress completed'
  end
end
