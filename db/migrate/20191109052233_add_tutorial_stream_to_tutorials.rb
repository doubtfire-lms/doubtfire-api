class AddTutorialStreamToTutorials < ActiveRecord::Migration
  def change
    add_reference :tutorials, :tutorial_stream, foreign_key: true, index: true
  end
end
