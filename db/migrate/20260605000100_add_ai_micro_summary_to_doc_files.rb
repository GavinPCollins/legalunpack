class AddAiMicroSummaryToDocFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :doc_files, :ai_micro_summary, :string
  end
end
