class CreateCompetencyFrameworkFoundation < ActiveRecord::Migration[8.0]
  def change
    create_table :skill_frameworks do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :version, null: false
      t.text :description
      t.boolean :archived, null: false, default: false
      t.timestamps
      t.index [:code, :version], unique: true
    end

    create_table :skills do |t|
      t.references :skill_framework, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :archived, null: false, default: false
      t.timestamps
      t.index [:skill_framework_id, :code], unique: true
    end

    create_table :skill_levels do |t|
      t.references :skill, null: false
      t.string :name, null: false
      t.integer :rank, null: false
      t.text :description
      t.timestamps
      t.index [:skill_id, :rank], unique: true
    end

    create_table :courses do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :version, null: false
      t.string :kind, null: false
      t.text :description
      t.timestamps
      t.index [:code, :version], unique: true
    end

    create_table :course_frameworks do |t|
      t.references :course, null: false
      t.references :skill_framework, null: false
      t.timestamps
      t.index [:course_id, :skill_framework_id], unique: true, name: 'idx_course_frameworks_unique'
    end

    create_table :unit_definitions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :version, null: false
      t.timestamps
      t.index [:code, :version], unique: true
    end

    create_table :course_unit_definitions do |t|
      t.references :course, null: false
      t.references :unit_definition, null: false
      t.timestamps
      t.index [:course_id, :unit_definition_id], unique: true, name: 'idx_course_unit_definitions_unique'
    end

    create_table :course_skill_requirements do |t|
      t.references :course, null: false
      t.references :skill, null: false
      t.references :skill_level, null: false
      t.timestamps
      t.index [:course_id, :skill_id], unique: true, name: 'idx_course_skill_requirements_unique'
    end

    create_table :unit_definition_skill_requirements do |t|
      t.references :unit_definition, null: false
      t.references :skill, null: false
      t.references :skill_level, null: false
      t.timestamps
      t.index [:unit_definition_id, :skill_id], unique: true, name: 'idx_unit_definition_skill_requirements_unique'
    end

    create_table :course_enrolments do |t|
      t.references :course, null: false
      t.references :user, null: false
      t.timestamps
      t.index [:course_id, :user_id], unique: true
    end

    add_reference :units, :unit_definition

    create_table :task_definition_skill_mappings do |t|
      t.references :task_definition, null: false, index: { name: 'idx_task_definition_skill_mappings_on_task_definition' }
      t.references :skill, null: false
      t.references :skill_level, null: false
      t.timestamps
      t.index [:task_definition_id, :skill_id], unique: true, name: 'idx_task_definition_skill_mappings_unique'
    end

    add_column :task_definitions, :allow_student_skill_selection, :boolean, null: false, default: false

    create_table :skill_evidences do |t|
      t.references :task, null: false
      t.references :skill_level, null: false
      t.string :submission_key, null: false
      t.datetime :submitted_at, null: false
      t.datetime :endorsed_at
      t.datetime :superseded_at
      t.datetime :archived_at
      t.timestamps
      t.index [:task_id, :submission_key, :skill_level_id], unique: true, name: 'idx_skill_evidence_unique_claim'
      t.index [:task_id, :superseded_at], name: 'idx_skill_evidence_current'
    end

    reversible do |direction|
      direction.up { backfill_unit_definitions }
    end
  end

  private

  def backfill_unit_definitions
    definitions = {}
    select_all('SELECT id, code, name, description FROM units ORDER BY id').each do |unit|
      key = [unit['code'], unit['name'], unit['description']]
      definition_id = definitions[key]

      unless definition_id
        version = "legacy-#{unit['id']}"
        execute <<~SQL.squish
          INSERT INTO unit_definitions (code, name, description, version, created_at, updated_at)
          VALUES (#{connection.quote(unit['code'].presence || "unit-#{unit['id']}")},
                  #{connection.quote(unit['name'].presence || "Unit #{unit['id']}")},
                  #{connection.quote(unit['description'])}, #{connection.quote(version)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
        definition_id = select_value(<<~SQL.squish)
          SELECT id FROM unit_definitions
          WHERE code = #{connection.quote(unit['code'].presence || "unit-#{unit['id']}")}
            AND version = #{connection.quote(version)}
        SQL
        definitions[key] = definition_id
      end

      execute "UPDATE units SET unit_definition_id = #{definition_id.to_i} WHERE id = #{unit['id'].to_i}"
    end
  end
end
