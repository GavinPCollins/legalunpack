class Document < ApplicationRecord
  belongs_to :user

  has_many :doc_files, dependent: :destroy
  has_many :clauses, dependent: :destroy
end
