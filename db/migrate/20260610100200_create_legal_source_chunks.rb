class CreateLegalSourceChunks < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:legal_source_chunks)

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

  def down
    drop_table :legal_source_chunks if table_exists?(:legal_source_chunks)
  end
end
