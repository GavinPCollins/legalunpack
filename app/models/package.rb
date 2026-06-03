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

  def extraction_complete?
    doc_files.any? && doc_files.all? { |doc_file| doc_file.extraction_status == "complete" }
  end

  def extraction_failed?
    doc_files.any? { |doc_file| doc_file.extraction_status == "failed" }
  end

  def extraction_in_progress?
    doc_files.any? { |doc_file| %w[pending processing].include?(doc_file.extraction_status) }
  end

  def extracted_text_for_ai
    doc_files
      .select { |doc_file| doc_file.extraction_status == "complete" && doc_file.extracted_text.present? }
      .map do |doc_file|
        filename = doc_file.file.attached? ? doc_file.file.filename.to_s : "Untitled file"

        <<~TEXT.strip
          File: #{filename}

          #{doc_file.extracted_text}
        TEXT
      end
      .join("\n\n---\n\n")
  end
end
