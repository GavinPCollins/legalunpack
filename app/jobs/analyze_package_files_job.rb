class AnalyzePackageFilesJob < ApplicationJob
  queue_as :default

  def perform(package)
    # Analyze every file in the package that has not already completed AI analysis.
    package.doc_files.where.not(ai_status: "complete").find_each do |doc_file|
      ExtractFileText.save!(doc_file) unless ready_for_analysis?(doc_file)
      doc_file.reload
      next unless ready_for_analysis?(doc_file)

      AnalyzeDocFileWithAi.save!(doc_file)
    rescue StandardError => error
      Rails.logger.warn("AI analysis failed for DocFile #{doc_file.id}: #{error.class} - #{error.message}")
    end
  end

  private

  def ready_for_analysis?(doc_file)
    doc_file.extraction_status == "complete" && doc_file.extracted_text.present?
  end
end
