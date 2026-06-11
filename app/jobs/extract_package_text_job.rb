class ExtractPackageTextJob < ApplicationJob
  queue_as :default

  def perform(package)
    # EXTRACT EACH FILE
    package.doc_files.active.needs_text_extraction.find_each do |doc_file|
      ExtractFileText.save!(doc_file)
    rescue StandardError => error
      Rails.logger.warn("Text extraction failed for DocFile #{doc_file.id}: #{error.class} - #{error.message}")
    end
  end
end
