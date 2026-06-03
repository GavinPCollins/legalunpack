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

  belongs_to :package
  has_one_attached :file

  validates :file, presence: true
  validate :file_content_type
  validate :file_size

  private

  def file_content_type
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)

    errors.add(:file, "must be a PDF, DOCX, TXT, or RTF file")
  end

  def file_size
    return unless file.attached?
    return if file.blob.byte_size <= MAX_FILE_SIZE

    errors.add(:file, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte} MB")
  end
end
