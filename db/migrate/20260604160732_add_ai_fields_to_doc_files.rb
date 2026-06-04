class AddAiFieldsToDocFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :doc_files, :ai_status, :string, default: "pending", null: false
    add_column :doc_files, :ai_summary, :text
    add_column :doc_files, :ai_error, :text
    add_column :doc_files, :ai_processed_at, :datetime
  end
end
