require_all 'lib/helpers'

namespace :db do
  desc 'Synchronise enrolments in the active units within the current teaching period'
  task sync_enrolments: [:environment] do
    TeachingPeriod.where('? >= start_date', Time.zone.now + 2.weeks).where('? <= end_date', Time.zone.now).find_each do |tp|
      tp.units.each do |unit|
        unit.sync_enrolments
        sleep(1)
      end
    end
  end
end
