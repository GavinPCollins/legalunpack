require "test_helper"
require "rake"

class LegalSourcesTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "legal_sources:discover" }
    @source_list_path = Rails.root.join("config/legal_sources.yml")
    @original_source_list = @source_list_path.read
    @source_directory = Rails.root.join("tmp/test_legal_sources")
    FileUtils.mkdir_p(@source_directory)
  end

  teardown do
    @source_list_path.write(@original_source_list)
    FileUtils.rm_rf(@source_directory)
    %w[DIR JURISDICTION SOURCE_TYPE AUTHORITY_LEVEL PUBLISHER].each { |key| ENV.delete(key) }
  end

  test "discovers local files and appends yaml catalogue entries" do
    pdf_path = @source_directory.join("refunds-and-returns.pdf")
    pdf_path.write("%PDF sample")
    ENV["DIR"] = @source_directory.relative_path_from(Rails.root).to_s

    Rake::Task["legal_sources:discover"].reenable
    capture_io { Rake::Task["legal_sources:discover"].invoke }

    source_list = YAML.safe_load_file(@source_list_path, aliases: false)
    discovered = source_list.find { |entry| entry["source_path"] == "tmp/test_legal_sources/refunds-and-returns.pdf" }

    assert_equal "Refunds And Returns", discovered["title"]
    assert_equal "VIC", discovered["jurisdiction"]
    assert_equal "regulator_guidance", discovered["source_type"]
    assert_equal "guidance", discovered["authority_level"]
    assert_equal "Consumer Affairs Victoria", discovered["publisher"]
    assert_equal "pdf", discovered["source_format"]
  end
end
