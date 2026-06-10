class AddWorkflowFieldsToFlags < ActiveRecord::Migration[8.1]
  def change
    add_column :flags, :category, :string
    add_column :flags, :suggested_action, :text
    add_column :flags, :resolution_note, :text

    add_index :flags, :category
  end
end
