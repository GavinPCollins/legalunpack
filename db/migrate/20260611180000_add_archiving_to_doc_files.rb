class AddArchivingToDocFiles < ActiveRecord::Migration[8.1]
  def up
    add_column :doc_files, :archived_at, :datetime unless column_exists?(:doc_files, :archived_at)

    unless column_exists?(:doc_files, :replaced_by_doc_file_id)
      add_reference :doc_files,
                    :replaced_by_doc_file,
                    foreign_key: { to_table: :doc_files, on_delete: :nullify },
                    index: true
    end
  end

  def down
    remove_reference :doc_files, :replaced_by_doc_file, foreign_key: true if column_exists?(:doc_files, :replaced_by_doc_file_id)
    remove_column :doc_files, :archived_at if column_exists?(:doc_files, :archived_at)
  end
end
