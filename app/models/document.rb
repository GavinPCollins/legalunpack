class Document < ApplicationRecord
  belongs_to :user, foreign_key: :id_user

  has_many :doc_files, dependent: :destroy
  has_many :clauses, dependent: :destroy
end
