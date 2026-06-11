class AddNoteToFlags < ActiveRecord::Migration[8.1]
  def change
    add_column :flags, :note, :text
  end
end
