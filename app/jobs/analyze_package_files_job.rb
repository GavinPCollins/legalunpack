class AnalyzePackageFilesJob < ApplicationJob
  queue_as :default

  def perform(package)
    # ANALYZE EACH FILE THAT HAS EXTRACTED TEXT
    package.doc_files.ready_for_ai.find_each do |doc_file|
      AnalyzeDocFileWithAi.save!(doc_file)
    rescue StandardError => error
      Rails.logger.warn("AI analysis failed for DocFile #{doc_file.id}: #{error.class} - #{error.message}")
    end
  end
end
