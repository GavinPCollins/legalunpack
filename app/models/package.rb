class Package < ApplicationRecord
  # CODEX search function updates
  include PgSearch::Model

  belongs_to :user

  has_many :doc_files, dependent: :destroy
  has_many :clauses, dependent: :destroy
  has_many :file_blobs, through: :doc_files, source: :file_blob

  # CODEX search function updates
  pg_search_scope :search_by_name_and_filename,
                  against: :name,
                  associated_against: {
                    file_blobs: :filename
                  },
                  using: {
                    tsearch: { prefix: true }
                  }

  validates :name, presence: { message: "Must name package" }
end
