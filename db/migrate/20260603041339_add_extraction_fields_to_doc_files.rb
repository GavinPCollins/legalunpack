class AddExtractionFieldsToDocFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :doc_files, :extracted_text, :text
    add_column :doc_files, :extraction_status, :string
    add_column :doc_files, :extraction_error, :text
    add_column :doc_files, :extracted_at, :datetime
  end
end
