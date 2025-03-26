class AddPolymorphicAssociationToLearningOutcomes < ActiveRecord::Migration[7.1]
  def up

    # add the polymorphic association columns
    add_column :learning_outcomes, :context_id, :bigint
    add_column :learning_outcomes, :context_type, :string

    # migrate the learning outcomes to the new polymorphic association
    say_with_time "Migrating learning outcomes to the new polymorphic association" do
      execute <<-SQL.squish
        UPDATE learning_outcomes
        SET context_id = unit_id, context_type = 'Unit'
        WHERE unit_id IS NOT NULL
      SQL
    end

    # add the polymorphic association index
    add_index :learning_outcomes, [:context_id, :context_type], name: "index_learning_outcomes_on_context_id_and_context_type"
    add_index :learning_outcomes, [:abbreviation, :context_type, :context_id], unique: true, name: "index_learning_outcomes_on_abbreviation_and_context"

    # remove the unit id column and indexes
    remove_index :learning_outcomes, name: "index_learning_outcomes_on_unit_id"
    remove_index :learning_outcomes, name: "index_learning_outcomes_on_abbreviation_and_unit_id"
    remove_column :learning_outcomes, :unit_id, :bigint
  end

  def down
    # add the unit id column
    add_column :learning_outcomes, :unit_id, :bigint

    # add the unit id index
    add_index :learning_outcomes, [:unit_id], name: "index_learning_outcomes_on_unit_id"
    add_index :learning_outcomes, [:abbreviation, :unit_id], unique: true, name: "index_learning_outcomes_on_abbreviation_and_unit_id"

    # migrate the learning outcomes back to the old association
    say_with_time "Migrating learning outcomes back to the old association" do
      execute <<-SQL.squish
        UPDATE learning_outcomes
        SET unit_id = context_id
        WHERE context_type = 'Unit'
      SQL
    end

    # remove the polymorphic association columns
    remove_index :learning_outcomes, name: "index_learning_outcomes_on_context_id_and_context_type"
    remove_column :learning_outcomes, :context_id, :bigint
    remove_column :learning_outcomes, :context_type, :string
  end
end
