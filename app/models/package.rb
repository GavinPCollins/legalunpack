require "pg_search/model"

class Package < ApplicationRecord
  # CODEX search function updates
  include PgSearch::Model

  belongs_to :user

  has_many :doc_files, dependent: :destroy
  has_many :active_doc_files, -> { active }, class_name: "DocFile"
  has_many :clauses, dependent: :destroy
  has_many :file_blobs, through: :doc_files, source: :file_blob
  has_many :chat_messages, dependent: :destroy

  # CODEX search function updates
  def self.search_by_name_and_filename(query)
    normalized_query = query.to_s.strip
    return none if normalized_query.blank?

    match_query = "%#{sanitize_sql_like(normalized_query)}%"

    left_joins(:doc_files)
      .joins(package_file_attachment_join_sql)
      .joins(package_file_blob_join_sql)
      .where(
        "packages.name ILIKE :query OR (doc_files.archived_at IS NULL AND package_file_blobs.filename ILIKE :query)",
        query: match_query
      )
      .distinct
  end

  def self.package_file_attachment_join_sql
    <<~SQL.squish
      LEFT OUTER JOIN active_storage_attachments package_file_attachments
        ON package_file_attachments.record_type = 'DocFile'
        AND package_file_attachments.record_id = doc_files.id
        AND package_file_attachments.name = 'file'
    SQL
  end
  private_class_method :package_file_attachment_join_sql

  def self.package_file_blob_join_sql
    <<~SQL.squish
      LEFT OUTER JOIN active_storage_blobs package_file_blobs
        ON package_file_blobs.id = package_file_attachments.blob_id
    SQL
  end
  private_class_method :package_file_blob_join_sql

  pg_search_scope :search_by_ai_summary_and_clauses,
                  associated_against: {
                    doc_files: :ai_summary,
                    clauses: %i[title content summary risk_level]
                  },
                  using: {
                    tsearch: { prefix: true }
                  }

  validates :name, presence: { message: "Must name package" }

  # CHECK EXTRACTION COMPLETE
  def extraction_complete?
    active_doc_files.any? && active_doc_files.all? { |doc_file| doc_file.extraction_status == "complete" }
  end

  # CHECK EXTRACTION FAILED
  def extraction_failed?
    active_doc_files.any? { |doc_file| doc_file.extraction_status == "failed" }
  end

  # CHECK EXTRACTION IN PROGRESS
  def extraction_in_progress?
    active_doc_files.any? { |doc_file| %w[pending processing].include?(doc_file.extraction_status) }
  end
end
