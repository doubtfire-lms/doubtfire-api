# frozen_string_literal: true

namespace :db do
  desc 'Seed (or refresh) the SFIA 9 skills and generic attributes from lib/assets/skill_frameworks/sfia_9.json'
  task seed_sfia: [:skip_prod, :environment] do
    skills = JSON.parse(Rails.root.join('lib/assets/skill_frameworks/sfia_9.json').read)

    ActiveRecord::Base.transaction do
      framework = SkillFramework.find_or_initialize_by(code: 'SFIA', version: 'Version 9')
      framework.update!(
        name: 'SFIA - Skills Framework for the Information Age',
        description: 'The global skills and competency framework for the digital world, defining skills across seven levels of responsibility.'
      )

      skills.each do |data|
        skill = framework.skills.find_or_initialize_by(code: data['code'])
        skill.update!(name: data['name'], description: data['description'])

        data['levels'].each do |level_data|
          level = skill.skill_levels.find_or_initialize_by(rank: level_data['rank'])
          level.update!(name: level_data['name'], description: level_data['description'])
        end
      end

      puts "Seeded #{framework.name} (#{framework.version}): #{skills.size} skills, #{skills.sum { |s| s['levels'].size }} levels"
    end
  end
end
