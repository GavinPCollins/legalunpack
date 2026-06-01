class CreateClauses < ActiveRecord::Migration[8.1]
  def change
    create_table :clauses do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end
  end
end
