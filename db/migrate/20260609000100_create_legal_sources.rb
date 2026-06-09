class CreateLegalSources < ActiveRecord::Migration[8.1]
  def change
    create_table :legal_sources do |t|
      t.string :title, null: false
      t.string :citation
      t.string :jurisdiction, null: false
      t.string :source_type, null: false
      t.string :authority_level, null: false
      t.string :publisher
      t.string :source_url, null: false
      t.string :source_format, null: false
      t.text :raw_text
      t.datetime :imported_at

      t.timestamps
    end

    add_index :legal_sources, :source_url, unique: true
    add_index :legal_sources, [ :jurisdiction, :source_type ]
  end
end
