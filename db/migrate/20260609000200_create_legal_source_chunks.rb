class CreateLegalSourceChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :legal_source_chunks do |t|
      t.references :legal_source, null: false, foreign_key: true
      t.string :section_label
      t.string :heading
      t.text :content, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :legal_source_chunks, [ :legal_source_id, :position ], unique: true
  end
end
