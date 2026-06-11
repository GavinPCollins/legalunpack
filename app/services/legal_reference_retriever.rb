require "set"

class LegalReferenceRetriever
  DEFAULT_LIMIT = 5
  CANDIDATE_MULTIPLIER = 10
  MINIMUM_CANDIDATES = 25
  MINIMUM_RANK = 0.0001
  QUERY_STOP_WORDS = %w[a an and are as at be by for from in is it of on or that the this to with].freeze

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

    def source_type
      legal_source.source_type
    end

    def source_url
      legal_source.source_url
    end

    def heading
      chunk.heading.presence || chunk.section_label
    end

    def citation
      [ title, pinpoint ].compact_blank.join(", ")
    end

    def pinpoint
      chunk.section_label.presence || provision_from_heading
    end

    def content
      chunk.content
    end

    private

    def provision_from_heading
      heading.to_s.match(/\A((?:section|s|regulation|reg|clause|part|division|schedule)\s+\d+[a-z]*|[0-9]+[A-Z]{0,3}[a-z]?)\b/i)&.[](1)
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

    chunks = search_scope
      .search_by_content(query)
      .with_pg_search_rank
      .includes(:legal_source)
      .limit(candidate_limit)
      .select { |chunk| chunk.pg_search_rank >= MINIMUM_RANK }
      .sort_by { |chunk| -reference_score(chunk) }
      .first(limit)

    chunks.map.with_index(1) do |chunk, index|
      Result.new(number: index, chunk: chunk)
    end
  end

  private

  attr_reader :query, :jurisdiction, :limit

  def candidate_limit
    [ limit * CANDIDATE_MULTIPLIER, MINIMUM_CANDIDATES ].max
  end

  def reference_score(chunk)
    chunk.pg_search_rank.to_f + heading_score(chunk) + source_authority_score(chunk)
  end

  def heading_score(chunk)
    heading = normalize(chunk.heading.presence || chunk.section_label)
    return 0.0 if heading.blank?

    score = 0.0
    normalized_query = normalize(query)
    score += 2.0 if normalized_query.present? && heading.include?(normalized_query)

    heading_terms = heading.split.to_set
    overlap = query_terms.count { |term| heading_terms.include?(term) }
    score += overlap * 0.35
    score += 1.0 if overlap >= [ query_terms.size, 3 ].min && overlap.positive?
    score
  end

  def source_authority_score(chunk)
    case chunk.legal_source.source_type
    when "act", "regulation"
      0.05
    else
      0.0
    end
  end

  def query_terms
    @query_terms ||= normalize(query).split.reject { |term| QUERY_STOP_WORDS.include?(term) || term.length < 3 }
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def search_scope
    scope = LegalSourceChunk.all
    return scope if jurisdiction.blank?

    scope.where(legal_source_id: LegalSource.where(jurisdiction: jurisdiction).select(:id))
  end
end
