class DocFile < ApplicationRecord
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

  belongs_to :package
  has_many :clauses, dependent: :nullify
  has_one_attached :file

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

  # SET DEFAULT STATUS
  after_initialize :set_default_statuses, if: :new_record?

  private

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
