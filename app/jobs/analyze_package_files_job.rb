class AnalyzePackageFilesJob < ApplicationJob
  queue_as :default

  def perform(package)
    # Analyze every file in the package that has not already completed AI analysis.
    files = package.doc_files.where.not(ai_status: "complete").order(:analysis_position, :created_at, :id)

    files.each do |doc_file|
      stage = ready_for_analysis?(doc_file) ? "analyzing_clauses" : "extracting_text"
      doc_file.update_columns(analysis_stage: stage, updated_at: Time.current)
      ExtractFileText.save!(doc_file) unless ready_for_analysis?(doc_file)
      doc_file.reload
      next unless ready_for_analysis?(doc_file)

      doc_file.update_columns(analysis_stage: "analyzing_clauses", updated_at: Time.current)
      AnalyzeDocFileWithAi.save!(doc_file)
    rescue StandardError => error
      doc_file.update_columns(
        ai_status: "failed",
        ai_error: error.message,
        ai_processed_at: nil,
        analysis_stage: nil,
        updated_at: Time.current
      ) unless doc_file.destroyed?
      Rails.logger.warn("AI analysis failed for DocFile #{doc_file.id}: #{error.class} - #{error.message}")
    end
  end

  private

  def ready_for_analysis?(doc_file)
    doc_file.extraction_status == "complete" && doc_file.extracted_text.present?
  end
end
