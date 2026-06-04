class AddAiFieldsToClauses < ActiveRecord::Migration[8.1]
  def change
    add_reference :clauses, :doc_file, foreign_key: true
    add_column :clauses, :title, :string
    add_column :clauses, :risk_level, :string
    add_column :clauses, :summary, :text
    add_column :clauses, :position, :integer
  end
end
