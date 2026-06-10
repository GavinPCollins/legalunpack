class CreateFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :flags do |t|
      t.references :clause, null: false, foreign_key: true
      t.string :name, null: false
      t.text :reason
      t.string :level
      t.boolean :resolved, null: false, default: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :flags, :level
    add_index :flags, :resolved
  end
end
