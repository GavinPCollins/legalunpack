require "test_helper"
require "zip"

class ExtractFileTextTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "extract@example.com", password: "password", username: "extract")
    package = user.packages.create!(name: "Lease review")

    @doc_file = package.doc_files.create!(
      file: {
        io: StringIO.new("Sample legal text."),
        filename: "sample.txt",
        content_type: "text/plain"
      }
    )
  end

  test "extracts text from a plain text file" do
    assert_equal "Sample legal text.", ExtractFileText.call(@doc_file)
  end

  test "extracts text from a PDF file" do
    @doc_file.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "sample.pdf",
      content_type: "application/pdf"
    )

    assert_includes ExtractFileText.call(@doc_file), "Sample PDF legal text."
  end

  test "extracts text from a DOCX file" do
    @doc_file.file.attach(
      io: generated_docx_io("Sample DOCX legal text."),
      filename: "sample.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )

    assert_includes ExtractFileText.call(@doc_file), "Sample DOCX legal text."
  end

  test "extracts text from an RTF file" do
    @doc_file.file.attach(
      io: StringIO.new("{\\rtf1\\ansi\\b Sample RTF legal text.\\b0}"),
      filename: "sample.rtf",
      content_type: "application/rtf"
    )

    assert_equal "Sample RTF legal text.", ExtractFileText.call(@doc_file)
  end

  test "normalizes extracted text whitespace" do
    @doc_file.file.attach(
      io: StringIO.new("  First   line\r\n\r\n\r\nSecond\t\tline  "),
      filename: "messy.txt",
      content_type: "text/plain"
    )

    assert_equal "First line\n\nSecond line", ExtractFileText.call(@doc_file)
  end

  test "saves extracted text and marks extraction complete" do
    ExtractFileText.save!(@doc_file)

    @doc_file.reload

    assert_equal "Sample legal text.", @doc_file.extracted_text
    assert_equal "complete", @doc_file.extraction_status
    assert_nil @doc_file.extraction_error
    assert_not_nil @doc_file.extracted_at
  end

  test "marks extraction failed when parsing fails" do
    @doc_file.file.attach(
      io: StringIO.new("fake docx"),
      filename: "sample.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )

    assert_raises Zip::Error do
      ExtractFileText.save!(@doc_file)
    end

    @doc_file.reload

    assert_equal "failed", @doc_file.extraction_status
    assert_equal "Zip end of central directory signature not found", @doc_file.extraction_error
    assert_nil @doc_file.extracted_at
  end

  private

  def generated_docx_io(text)
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
      XML

      zip.put_next_entry("_rels/.rels")
      zip.write <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
      XML

      zip.put_next_entry("word/_rels/document.xml.rels")
      zip.write <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
      XML

      zip.put_next_entry("word/styles.xml")
      zip.write <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
      XML

      zip.put_next_entry("word/document.xml")
      zip.write <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p>
              <w:r>
                <w:t>#{ERB::Util.html_escape(text)}</w:t>
              </w:r>
            </w:p>
          </w:body>
        </w:document>
      XML
    end

    StringIO.new(buffer.string)
  end
end
