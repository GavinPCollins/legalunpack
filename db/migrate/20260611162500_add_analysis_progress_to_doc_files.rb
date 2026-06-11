class AddAnalysisProgressToDocFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :doc_files, :analysis_stage, :string
    add_column :doc_files, :analysis_position, :integer
    add_column :doc_files, :analysis_total, :integer
  end
end
