require "json"
require "pg_search/model"

class DocFile < ApplicationRecord
  # CODEX file summary updates
  include PgSearch::Model

  MAX_FILE_SIZE = 25.megabytes
  ALLOWED_CONTENT_TYPES = [
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/rtf",
    "application/x-rtf",
    "text/rtf",
    "text/plain"
  ].freeze

  EXTRACTION_STATUSES = %w[pending processing complete failed].freeze
  AI_STATUSES = %w[pending processing complete failed].freeze
  ANALYSIS_STAGES = %w[
    waiting
    extracting_text
    analyzing_clauses
    checking_sources
    reviewing_concerns
    preparing_results
  ].freeze
  ANALYSIS_STAGE_LABELS = {
    "waiting" => "Waiting to start",
    "extracting_text" => "Extracting text",
    "analyzing_clauses" => "Analyzing clauses",
    "checking_sources" => "Checking relevant sources",
    "reviewing_concerns" => "Reviewing potential concerns",
    "preparing_results" => "Preparing your results"
  }.freeze

  belongs_to :package
  has_many :clauses, dependent: :nullify
  has_one_attached :file

  # CODEX file summary updates
  pg_search_scope :search_by_ai_summary,
                  against: :ai_summary,
                  using: {
                    tsearch: { prefix: true }
                  }

  # AI-READY FILES
  scope :ready_for_ai, -> {
    where(extraction_status: "complete")
      .where.not(extracted_text: [ nil, "" ])
      .where.not(ai_status: "complete")
  }
  scope :needs_text_extraction, -> {
    where(extraction_status: [ nil, "pending" ])
      .or(where(extraction_status: "complete", extracted_text: [ nil, "" ]))
  }

  validates :file, presence: true
  validate :file_content_type
  validate :file_size
  validates :extraction_status, inclusion: { in: EXTRACTION_STATUSES }
  validates :ai_status, inclusion: { in: AI_STATUSES }
  validates :analysis_stage, inclusion: { in: ANALYSIS_STAGES }, allow_nil: true

  # SET DEFAULT STATUS
  after_initialize :set_default_statuses, if: :new_record?

  def processing_error_message
    raw_error = ai_error.presence || extraction_error.presence
    return if raw_error.blank?

    parsed_error_message(raw_error) || raw_error
  end

  def analysis_progress_label
    ANALYSIS_STAGE_LABELS.fetch(analysis_stage, "Analyzing file")
  end

  def analysis_batch_label
    return "Analyzing file" unless analysis_position.present? && analysis_total.present?

    "Analyzing file #{analysis_position} of #{analysis_total}"
  end

  private

  def parsed_error_message(raw_error)
    json_start = raw_error.index("{")
    return if json_start.blank?

    parsed_error = JSON.parse(raw_error[json_start..])
    parsed_error["message"] || parsed_error.dig("error", "message")
  rescue JSON::ParserError, KeyError
    nil
  end

  # VALIDATE FILE TYPE
  def file_content_type
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)

    errors.add(:file, "must be a PDF, DOCX, TXT, or RTF file")
  end

  # VALIDATE FILE SIZE
  def file_size
    return unless file.attached?
    return if file.blob.byte_size <= MAX_FILE_SIZE

    errors.add(:file, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte} MB")
  end

  # DEFAULT TO PENDING
  def set_default_statuses
    self.extraction_status ||= "pending"
    self.ai_status ||= "pending"
  end
end
