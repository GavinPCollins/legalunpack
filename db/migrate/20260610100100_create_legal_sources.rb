class CreateLegalSources < ActiveRecord::Migration[8.1]
  def up
    if table_exists?(:legal_sources)
      change_column_null :legal_sources, :source_url, true if column_exists?(:legal_sources, :source_url)
      add_index :legal_sources, :source_url, unique: true, where: "source_url IS NOT NULL AND source_url <> ''" unless index_exists?(:legal_sources, :source_url)
      add_index :legal_sources, [ :jurisdiction, :source_type ] unless index_exists?(:legal_sources, [ :jurisdiction, :source_type ])
      return
    end

    create_table :legal_sources do |t|
      t.string :title, null: false
      t.string :citation
      t.string :jurisdiction, null: false
      t.string :source_type, null: false
      t.string :authority_level, null: false
      t.string :publisher
      t.string :source_url
      t.string :source_format, null: false
      t.text :raw_text
      t.datetime :imported_at

      t.timestamps
    end

    add_index :legal_sources, :source_url, unique: true, where: "source_url IS NOT NULL AND source_url <> ''"
    add_index :legal_sources, [ :jurisdiction, :source_type ]
  end

  def down
    drop_table :legal_sources unless table_exists?(:legal_source_chunks)
  end
end
