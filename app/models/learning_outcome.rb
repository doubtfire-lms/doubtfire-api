class LearningOutcome < ActiveRecord::Base
  include ApplicationHelper

  belongs_to :unit

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :related_task_definitions, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links, source: :task_definition # only link staff relations

  validates :abbreviation, uniqueness: { scope: :unit_id } # outcome names within a unit must be unique
  validates :description, length: { maximum: 4095, allow_blank: true }

  def self.csv_header
    %w(unit_code ilo_number abbreviation name description)
  end

  def add_csv_row(row)
    row << [unit.code, ilo_number, abbreviation, name, description]
  end

  def self.create_from_csv(unit, row, result)
    unit_code = row['unit_code']

    if unit_code != unit.code
      result[:ignored] << { row: row, message: "Invalid unit code. #{unit_code} does not match #{unit.code}" }
      return
    end

    ilo_number = row['ilo_number'].to_i

    abbr = row['abbreviation']
    if abbr.nil?
      result[:errors] << { row: row, message: 'Missing abbreviation' }
      return
    end

    name = row['name']
    if name.nil?
      result[:errors] << { row: row, message: 'Missing name' }
      return
    end

    description = row['description']
    if description.nil?
      result[:errors] << { row: row, message: 'Missing description' }
      return
    end

    outcome = LearningOutcome.find_or_create_by(unit_id: unit.id, abbreviation: abbr) do |outcome|
      outcome.name = name
      outcome.description = description
      outcome.ilo_number = ilo_number
    end

    outcome.save!

    result[:success] << if outcome.new_record?
                          { row: row, message: "Outcome #{abbr} created for unit" }
                        else
                          { row: row, message: "Outcome #{abbr} updated for unit" }
                        end
  end
end
