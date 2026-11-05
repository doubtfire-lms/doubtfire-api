require 'grape'

class CompetenciesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before { authenticated? }

  helpers do
    def require_competency_admin!
      error!({ error: 'Only administrators can manage competency curricula' }, 403) unless current_user.has_admin_capability?
    end

    def require_unit_definition_editor!(unit)
      return if current_user.has_admin_capability? || authorise?(current_user, unit, :update)

      error!({ error: 'Not authorised to change the unit definition for this offering' }, 403)
    end

    def level_data(level)
      {
        id: level.id,
        skill_id: level.skill_id,
        name: level.name,
        rank: level.rank,
        description: level.description
      }
    end

    def skill_data(skill)
      {
        id: skill.id,
        code: skill.code,
        name: skill.name,
        description: skill.description,
        archived: skill.archived,
        levels: skill.skill_levels.sort_by(&:rank).map { |level| level_data(level) }
      }
    end

    def framework_data(framework)
      {
        id: framework.id,
        code: framework.code,
        name: framework.name,
        version: framework.version,
        description: framework.description,
        archived: framework.archived,
        skills: framework.skills.sort_by(&:code).map { |skill| skill_data(skill) }
      }
    end

    def save_catalog_record!(record, attributes)
      record.assign_attributes(attributes)
      error!({ error: record.errors.full_messages.to_sentence }, 422) unless record.save

      record
    end

    def requirement_data(requirement)
      level = requirement.skill_level
      level_data(level).merge(
        skill_code: level.skill.code,
        skill_name: level.skill.name,
        skill_description: level.skill.description,
        framework_id: level.skill.skill_framework_id
      )
    end

    def course_data(course)
      {
        id: course.id,
        code: course.code,
        name: course.name,
        description: course.description,
        version: course.version,
        kind: course.kind,
        framework_ids: course.skill_framework_ids,
        unit_definition_ids: course.unit_definition_ids,
        required_skills: course.course_skill_requirements.includes(skill_level: :skill).map { |row| requirement_data(row) }
      }
    end

    def unit_definition_data(definition)
      {
        id: definition.id,
        code: definition.code,
        name: definition.name,
        description: definition.description,
        version: definition.version,
        required_skills: definition.unit_definition_skill_requirements.includes(skill_level: :skill).map { |row| requirement_data(row) }
      }
    end

    def replace_requirements!(owner, association_name, level_ids)
      levels = SkillLevel.includes(skill: :skill_framework).where(id: level_ids).index_by(&:id)
      error!({ error: 'An unknown skill level was selected' }, 422) unless levels.length == level_ids.uniq.length

      skills = level_ids.map { |id| levels.fetch(id).skill_id }
      error!({ error: 'Select at most one level per skill' }, 422) unless skills.uniq.length == skills.length

      if owner.is_a?(TaskDefinition)
        existing_level_ids = owner.task_definition_skill_mappings.pluck(:skill_level_id)
        archived_levels = levels.values.select do |level|
          (level.skill.archived || level.skill.skill_framework.archived) && !existing_level_ids.include?(level.id)
        end
        error!({ error: 'Archived framework skills cannot be added to tasks' }, 422) if archived_levels.any?
      end

      owner.public_send(association_name).delete_all
      level_ids.each do |id|
        level = levels.fetch(id)
        owner.public_send(association_name).create!(skill: level.skill, skill_level: level)
      end
    end
  end

  desc 'List skill frameworks and their skills'
  get '/skill_frameworks' do
    SkillFramework.includes(skills: :skill_levels).order(:code, :version).map { |framework| framework_data(framework) }
  end

  desc 'Create a skill framework version'
  params do
    requires :skill_framework, type: Hash do
      requires :code, type: String
      requires :name, type: String
      requires :version, type: String
      optional :description, type: String
      optional :archived, type: Boolean
    end
  end
  post '/skill_frameworks' do
    require_competency_admin!
    framework = save_catalog_record!(SkillFramework.new, params[:skill_framework].slice(:code, :name, :version, :description, :archived))
    framework_data(framework)
  end

  desc 'Update a skill framework version'
  params do
    requires :skill_framework, type: Hash do
      optional :code, type: String
      optional :name, type: String
      optional :version, type: String
      optional :description, type: String
      optional :archived, type: Boolean
    end
  end
  put '/skill_frameworks/:id' do
    require_competency_admin!
    framework = save_catalog_record!(SkillFramework.find(params[:id]), params[:skill_framework].slice(:code, :name, :version, :description, :archived))
    framework_data(framework)
  end

  desc 'Add a skill to a framework version'
  params do
    requires :skill, type: Hash do
      requires :code, type: String
      requires :name, type: String
      optional :description, type: String
      optional :archived, type: Boolean
    end
  end
  post '/skill_frameworks/:framework_id/skills' do
    require_competency_admin!
    framework = SkillFramework.find(params[:framework_id])
    skill = save_catalog_record!(framework.skills.build, params[:skill].slice(:code, :name, :description, :archived))
    skill_data(skill)
  end

  desc 'Update a skill'
  params do
    requires :skill, type: Hash do
      optional :code, type: String
      optional :name, type: String
      optional :description, type: String
      optional :archived, type: Boolean
    end
  end
  put '/skills/:id' do
    require_competency_admin!
    skill = save_catalog_record!(Skill.find(params[:id]), params[:skill].slice(:code, :name, :description, :archived))
    skill_data(skill)
  end

  desc 'Add a level to a skill'
  params do
    requires :skill_level, type: Hash do
      requires :name, type: String
      requires :rank, type: Integer
      optional :description, type: String
    end
  end
  post '/skills/:skill_id/levels' do
    require_competency_admin!
    skill = Skill.find(params[:skill_id])
    level = save_catalog_record!(skill.skill_levels.build, params[:skill_level].slice(:name, :rank, :description))
    level_data(level)
  end

  desc 'Update a skill level'
  params do
    requires :skill_level, type: Hash do
      optional :name, type: String
      optional :rank, type: Integer
      optional :description, type: String
    end
  end
  put '/skill_levels/:id' do
    require_competency_admin!
    level = save_catalog_record!(SkillLevel.find(params[:id]), params[:skill_level].slice(:name, :rank, :description))
    level_data(level)
  end

  desc 'List courses for curriculum administration'
  get '/courses' do
    require_competency_admin!
    Course.order(:code, :version).map { |course| course_data(course) }
  end

  desc 'Create a course version'
  params do
    requires :course, type: Hash do
      requires :code, type: String
      requires :name, type: String
      requires :version, type: String
      requires :kind, type: String
      optional :description, type: String
      optional :framework_ids, type: Array[Integer]
      optional :unit_definition_ids, type: Array[Integer]
      optional :skill_level_ids, type: Array[Integer]
    end
  end
  post '/courses' do
    require_competency_admin!
    attributes = params[:course]
    course = Course.transaction do
      record = Course.create!(attributes.slice(:code, :name, :version, :kind, :description))
      record.skill_framework_ids = attributes[:framework_ids] || []
      record.unit_definition_ids = attributes[:unit_definition_ids] || []
      replace_requirements!(record, :course_skill_requirements, attributes[:skill_level_ids] || [])
      record
    end
    course_data(course)
  end

  desc 'Update a course version'
  params do
    requires :course, type: Hash do
      optional :code, type: String
      optional :name, type: String
      optional :version, type: String
      optional :kind, type: String
      optional :description, type: String
      optional :framework_ids, type: Array[Integer]
      optional :unit_definition_ids, type: Array[Integer]
      optional :skill_level_ids, type: Array[Integer]
    end
  end
  put '/courses/:id' do
    require_competency_admin!
    attributes = params[:course]
    course = Course.find(params[:id])
    Course.transaction do
      course.update!(attributes.slice(:code, :name, :version, :kind, :description))
      course.skill_framework_ids = attributes[:framework_ids] if attributes.key?(:framework_ids)
      course.unit_definition_ids = attributes[:unit_definition_ids] if attributes.key?(:unit_definition_ids)
      if attributes.key?(:skill_level_ids)
        replace_requirements!(course, :course_skill_requirements, attributes[:skill_level_ids])
      end
    end
    course_data(course.reload)
  end

  desc 'List unit definition versions'
  get '/unit_definitions' do
    require_competency_admin!
    UnitDefinition.order(:code, :version).map { |definition| unit_definition_data(definition) }
  end

  desc 'Create a unit definition version'
  params do
    requires :unit_definition, type: Hash do
      requires :code, type: String
      requires :name, type: String
      requires :version, type: String
      optional :description, type: String
      optional :skill_level_ids, type: Array[Integer]
    end
  end
  post '/unit_definitions' do
    require_competency_admin!
    attributes = params[:unit_definition]
    definition = UnitDefinition.transaction do
      record = UnitDefinition.create!(attributes.slice(:code, :name, :version, :description))
      replace_requirements!(record, :unit_definition_skill_requirements, attributes[:skill_level_ids] || [])
      record
    end
    unit_definition_data(definition)
  end

  desc 'Update a unit definition version'
  params do
    requires :unit_definition, type: Hash do
      optional :code, type: String
      optional :name, type: String
      optional :version, type: String
      optional :description, type: String
      optional :skill_level_ids, type: Array[Integer]
    end
  end
  put '/unit_definitions/:id' do
    require_competency_admin!
    attributes = params[:unit_definition]
    definition = UnitDefinition.find(params[:id])
    if attributes[:code].present? && attributes[:code] != definition.code && definition.units.exists?
      error!({ error: 'Create a new unit definition before changing the code of a linked version' }, 422)
    end

    UnitDefinition.transaction do
      definition.update!(attributes.slice(:code, :name, :version, :description))
      if attributes.key?(:skill_level_ids)
        replace_requirements!(definition, :unit_definition_skill_requirements, attributes[:skill_level_ids])
      end
    end
    unit_definition_data(definition.reload)
  end

  desc 'List the unit definition versions an offering can use'
  get '/units/:unit_id/unit_definition' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Not authorised to view this unit' }, 403) unless authorise?(current_user, unit, :get_unit)

    {
      unit_definition_id: unit.unit_definition_id,
      options: UnitDefinition.where(code: unit.code).includes(:unit_definition_skill_requirements).order(:version).map do |definition|
        { id: definition.id, name: definition.name, version: definition.version, required_skill_count: definition.unit_definition_skill_requirements.size }
      end
    }
  end

  desc 'Assign a unit offering to a unit definition version'
  params do
    requires :unit_definition_id, type: Integer
  end
  put '/units/:unit_id/unit_definition' do
    unit = Unit.find(params[:unit_id])
    require_unit_definition_editor!(unit)
    definition = UnitDefinition.find(params[:unit_definition_id])
    error!({ error: 'The unit definition code must match the offering code' }, 422) unless definition.code == unit.code

    unit.update!(unit_definition_id: definition.id)
    unit.reload
    error!({ error: 'The unit definition update did not persist' }, 409) unless unit.unit_definition_id == definition.id

    { unit_id: unit.id, unit_definition_id: unit.unit_definition_id }
  end

  desc 'Unlink a unit offering from its unit definition version'
  delete '/units/:unit_id/unit_definition' do
    unit = Unit.find(params[:unit_id])
    require_unit_definition_editor!(unit)
    unit.update!(unit_definition: nil)
    unit.reload
    error!({ error: 'The unit definition unlink did not persist' }, 409) unless unit.unit_definition_id.nil?

    { unit_id: unit.id, unit_definition_id: nil }
  end

  desc 'Suggest skills for a unit from its definition and courses'
  get '/units/:unit_id/skill_suggestions' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Not authorised to view unit skills' }, 403) unless authorise?(current_user, unit, :get_unit)

    definition = unit.unit_definition
    next [] unless definition

    required = definition.unit_definition_skill_requirements.includes(skill_level: :skill).map(&:skill_level)
    course_levels = CourseSkillRequirement.joins(course: :course_unit_definitions)
                                          .where(course_unit_definitions: { unit_definition_id: definition.id })
                                          .includes(skill_level: :skill)
                                          .map(&:skill_level)
    rows = required.map { |level| level_data(level).merge(source: 'unit_definition') } +
           course_levels.map { |level| level_data(level).merge(source: 'course') }
    rows.uniq { |row| row[:id] }
  end

  desc 'Replace staff-defined skill mappings for a task definition'
  get '/units/:unit_id/task_definitions/:task_definition_id/skill_mappings' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Not authorised to view task skills' }, 403) unless authorise?(current_user, unit, :get_unit)

    definition = unit.task_definitions.find(params[:task_definition_id])
    definition.task_definition_skill_mappings.includes(skill_level: :skill).map { |row| requirement_data(row) }
  end

  desc 'Replace staff-defined skill mappings for a task definition'
  params do
    requires :skill_level_ids, type: Array[Integer]
  end
  put '/units/:unit_id/task_definitions/:task_definition_id/skill_mappings' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Not authorised to edit task skills' }, 403) unless authorise?(current_user, unit, :add_task_def)

    definition = unit.task_definitions.find(params[:task_definition_id])
    TaskDefinition.transaction do
      replace_requirements!(definition, :task_definition_skill_mappings, params[:skill_level_ids])
    end
    definition.task_definition_skill_mappings.includes(skill_level: :skill).map { |row| requirement_data(row) }
  end

  desc 'Show skill opportunities and evidence for a project'
  get '/projects/:project_id/skill_progress' do
    project = Project.find(params[:project_id])
    error!({ error: 'Not authorised to view project skills' }, 403) unless authorise?(current_user, project, :get)

    definitions = project.unit.task_definitions.includes(task_definition_skill_mappings: { skill_level: :skill })
    tasks_by_definition = project.tasks.includes(skill_evidences: { skill_level: :skill }).index_by(&:task_definition_id)
    {
      unit_definition: project.unit.unit_definition && unit_definition_data(project.unit.unit_definition),
      tasks: definitions.map do |definition|
        task = tasks_by_definition[definition.id]
        evidence = if task
                     task.skill_evidences.select { |row| row.superseded_at.nil? && row.archived_at.nil? }.map do |row|
                       requirement_data(row).merge(evidence_id: row.id, submitted_at: row.submitted_at, endorsed_at: row.endorsed_at)
                     end
                   else
                     []
                   end
        {
          task_definition_id: definition.id,
          abbreviation: definition.abbreviation,
          name: definition.name,
          task_id: task&.id,
          status: task&.task_status&.name,
          skills: definition.task_definition_skill_mappings.map { |row| requirement_data(row) },
          evidence: evidence
        }
      end
    }
  end
end
