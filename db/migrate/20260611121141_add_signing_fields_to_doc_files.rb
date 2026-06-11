class AddSigningFieldsToDocFiles < ActiveRecord::Migration[8.1]
  def up
    add_column :doc_files, :sign_by, :date unless column_exists?(:doc_files, :sign_by)
    add_column :doc_files, :signed, :boolean unless column_exists?(:doc_files, :signed)
  end

  def down
    # These columns may predate this migration, so a rollback must not remove them.
  end
end
