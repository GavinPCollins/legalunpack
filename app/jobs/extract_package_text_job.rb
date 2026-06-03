class ExtractPackageTextJob < ApplicationJob
  queue_as :default

  def perform(package)
    package.doc_files.find_each do |doc_file|
      ExtractFileText.save!(doc_file)
    rescue StandardError => error
      Rails.logger.warn("Text extraction failed for DocFile #{doc_file.id}: #{error.class} - #{error.message}")
    end
  end
end
