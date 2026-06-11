class AddEvidenceToFlags < ActiveRecord::Migration[8.1]
  def change
    add_column :flags, :evidence_basis, :string

    create_table :flag_legal_references do |t|
      t.references :flag, null: false, foreign_key: true
      t.references :legal_source_chunk, null: false, foreign_key: true

      t.timestamps
    end

    add_index :flag_legal_references,
              [ :flag_id, :legal_source_chunk_id ],
              unique: true,
              name: "index_flag_legal_references_uniqueness"
  end
end
