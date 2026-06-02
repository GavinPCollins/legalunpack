class CreateDocFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :doc_files do |t|
      t.references :package, null: false, foreign_key: true
      t.string :file_path

      t.timestamps
    end
  end
end
