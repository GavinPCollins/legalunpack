class RenameDocumentsToPackages < ActiveRecord::Migration[8.1]
  def up
    rename_table :documents, :packages if table_exists?(:documents) && !table_exists?(:packages)

    rename_document_reference :clauses
    rename_document_reference :doc_files
  end

  def down
    rename_package_reference :doc_files
    rename_package_reference :clauses

    rename_table :packages, :documents if table_exists?(:packages) && !table_exists?(:documents)
  end

  private

  def rename_document_reference(table_name)
    return unless column_exists?(table_name, :document_id)

    remove_foreign_key table_name, column: :document_id if foreign_key_exists?(table_name, column: :document_id)
    rename_column table_name, :document_id, :package_id
    rename_index table_name, "index_#{table_name}_on_document_id", "index_#{table_name}_on_package_id" if index_name_exists?(table_name, "index_#{table_name}_on_document_id")
    add_foreign_key table_name, :packages unless foreign_key_exists?(table_name, :packages)
  end

  def rename_package_reference(table_name)
    return unless column_exists?(table_name, :package_id)

    remove_foreign_key table_name, column: :package_id if foreign_key_exists?(table_name, column: :package_id)
    rename_column table_name, :package_id, :document_id
    rename_index table_name, "index_#{table_name}_on_package_id", "index_#{table_name}_on_document_id" if index_name_exists?(table_name, "index_#{table_name}_on_package_id")
    add_foreign_key table_name, :documents if table_exists?(:documents) && !foreign_key_exists?(table_name, :documents)
  end
end
