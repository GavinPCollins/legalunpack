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

  # CHECK EXTRACTION COMPLETE
  def extraction_complete?
    doc_files.any? && doc_files.all? { |doc_file| doc_file.extraction_status == "complete" }
  end

  # CHECK EXTRACTION FAILED
  def extraction_failed?
    doc_files.any? { |doc_file| doc_file.extraction_status == "failed" }
  end

  # CHECK EXTRACTION IN PROGRESS
  def extraction_in_progress?
    doc_files.any? { |doc_file| %w[pending processing].include?(doc_file.extraction_status) }
  end
end
