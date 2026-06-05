require "test_helper"

class AnalyzePackageFilesJobTest < ActiveJob::TestCase
  setup do
    user = User.create!(email: "ai-job@example.com", password: "password", username: "aijob")
    @package = user.packages.create!(name: "Lease review")

    @ready_doc_file = create_doc_file(
      filename: "ready.txt",
      extracted_text: "Ready legal text.",
      extraction_status: "complete"
    )
    @pending_doc_file = create_doc_file(
      filename: "pending.txt",
      extracted_text: "Pending legal text.",
      extraction_status: "pending"
    )
    @blank_doc_file = create_doc_file(
      filename: "blank.txt",
      extracted_text: "",
      extraction_status: "complete"
    )
  end

  test "analyzes only files ready for ai" do
    analyzed_ids = []

    stub_analyzer(lambda do |doc_file|
      analyzed_ids << doc_file.id
    end) do
      AnalyzePackageFilesJob.perform_now(@package)
    end


    assert_equal [ @ready_doc_file.id ], analyzed_ids
  end

  test "does not analyze files with complete ai analysis" do
    analyzed_doc_file = create_doc_file(
      filename: "already-analyzed.txt",
      extracted_text: "Already analyzed legal text.",
      extraction_status: "complete",
      ai_status: "complete"
    )
    analyzed_ids = []

    stub_analyzer(lambda do |doc_file|
      analyzed_ids << doc_file.id
    end) do
      AnalyzePackageFilesJob.perform_now(@package)
    end

    assert_equal [ @ready_doc_file.id ], analyzed_ids
    assert_not_includes analyzed_ids, analyzed_doc_file.id
  end

  test "continues analyzing remaining files when one file fails" do
    second_ready_doc_file = create_doc_file(
      filename: "second-ready.txt",
      extracted_text: "Second ready legal text.",
      extraction_status: "complete"
    )
    analyzed_ids = []

    stub_analyzer(lambda do |doc_file|
      analyzed_ids << doc_file.id
      raise "analysis failed" if doc_file.id == @ready_doc_file.id
    end) do
      AnalyzePackageFilesJob.perform_now(@package)
    end


    assert_equal [ @ready_doc_file.id, second_ready_doc_file.id ], analyzed_ids
  end

  private

  def create_doc_file(filename:, extracted_text:, extraction_status:, ai_status: "pending")
    @package.doc_files.create!(
      extracted_text: extracted_text,
      extraction_status: extraction_status,
      ai_status: ai_status,
      file: {
        io: StringIO.new(filename),
        filename: filename,
        content_type: "text/plain"
      }
    )
  end

  def stub_analyzer(handler)
    original_save = AnalyzeDocFileWithAi.method(:save!)
    AnalyzeDocFileWithAi.define_singleton_method(:save!) do |doc_file|
      handler.call(doc_file)
    end

    yield
  ensure
    AnalyzeDocFileWithAi.define_singleton_method(:save!, original_save) if original_save
  end
end
