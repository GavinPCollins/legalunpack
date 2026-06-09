class LegalReferenceRetriever
  DEFAULT_LIMIT = 5

  Result = Struct.new(:number, :chunk, keyword_init: true) do
    delegate :legal_source, to: :chunk

    def label
      "L#{number}"
    end

    def title
      legal_source.citation.presence || legal_source.title
    end

    def publisher
      legal_source.publisher
    end

    def jurisdiction
      legal_source.jurisdiction
    end

    def authority_level
      legal_source.authority_level
    end

    def source_url
      legal_source.source_url
    end

    def heading
      chunk.heading.presence || chunk.section_label
    end

    def content
      chunk.content
    end
  end

  def self.call(query:, jurisdiction: nil, limit: DEFAULT_LIMIT)
    new(query: query, jurisdiction: jurisdiction, limit: limit).call
  end

  def initialize(query:, jurisdiction: nil, limit: DEFAULT_LIMIT)
    @query = query.to_s.strip
    @jurisdiction = jurisdiction.to_s.strip.presence
    @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
  end

  def call
    return [] if query.blank?

    search_limit = jurisdiction.present? ? limit * 5 : limit
    chunks = LegalSourceChunk.search_by_content(query).includes(:legal_source).limit(search_limit)
    chunks = chunks.select { |chunk| chunk.legal_source.jurisdiction == jurisdiction } if jurisdiction.present?

    chunks.first(limit).map.with_index(1) do |chunk, index|
      Result.new(number: index, chunk: chunk)
    end
  end

  private

  attr_reader :query, :jurisdiction, :limit
end
