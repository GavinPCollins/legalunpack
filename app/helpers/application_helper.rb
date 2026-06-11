module ApplicationHelper
  def highlighted_search_text(text, query)
    return text if query.blank? || text.blank?

    highlight(
      text.to_s,
      search_terms(query),
      highlighter: '<mark class="rounded bg-yellow-100 px-0.5 text-yellow-950">\1</mark>'
    )
  end

  def highlighted_summary_text(text, query)
    return text if query.blank? || text.blank?

    highlighter = [
      '<mark class="rounded bg-cyan-50 px-0.5 font-semibold text-cyan-950"',
      'tabindex="-1" data-summary-highlight-target="match">\1</mark>'
    ].join(" ")

    highlight(
      text.to_s,
      search_terms(query),
      highlighter: highlighter
    )
  end

  def search_text_match?(text, query)
    return false if text.blank? || query.blank?

    normalized_text = text.to_s.downcase
    search_terms(query).any? { |term| normalized_text.include?(term.downcase) }
  end

  def search_match_count(text, query)
    return 0 if text.blank? || query.blank?

    search_terms(query).sum do |term|
      text.to_s.scan(/#{Regexp.escape(term)}/i).count
    end
  end

  def matching_ai_summary_blocks(doc_file, query)
    split_search_blocks(doc_file.ai_summary).select { |block| search_text_match?(block, query) }
  end

  def ai_summary_match_count(doc_file, query)
    search_match_count(doc_file.ai_summary, query)
  end

  def package_ai_summary_search_match_count(package, query)
    summary_matches = package.doc_files.sum { |doc_file| ai_summary_match_count(doc_file, query) }

    summary_matches + matching_clause_results(package, query).count
  end

  def matching_clause_results(package, query)
    package.clauses.sort_by { |clause| [clause.position || Float::INFINITY, clause.id || 0] }.select do |clause|
      [
        clause.title,
        clause.risk_level,
        clause.summary,
        clause.content
      ].any? { |value| search_text_match?(value, query) }
    end
  end

  def flag_priority_class(flag)
    case flag.level
    when "high" then "badge-danger"
    when "medium" then "badge-warning"
    when "low" then "badge-info"
    else "badge-neutral"
    end
  end

  def flag_priority_label(flag)
    flag.level.present? ? "#{flag.level.humanize} priority" : "Review"
  end

  def highest_priority_flag(flags)
    all_flags = Array(flags)
    active_flags = all_flags.reject(&:resolved?)
    considered_flags = active_flags.presence || all_flags

    considered_flags.max_by { |flag| { "high" => 3, "medium" => 2, "low" => 1 }.fetch(flag.level, 0) }
  end

  def flag_group_title(clause, flags)
    ordered_flags = Array(flags)
    return ordered_flags.first.name if ordered_flags.one?

    clause_name = clause.title.presence || "clause"
    return "#{ordered_flags.first.name} and #{ordered_flags.second.name}".truncate(100) if ordered_flags.size == 2

    "Multiple concerns in #{clause_name}"
  end

  def flag_group_summary(clause, flags)
    summaries = Array(flags).filter_map { |flag| flag.reason.presence }.uniq
    return summaries.first if summaries.one?
    return summaries.to_sentence if summaries.any?

    clause.summary.presence
  end

  private

  def search_terms(query)
    normalized_query = query.to_s.squish
    terms = normalized_query.split(/\s+/)
    terms.unshift(normalized_query) if normalized_query.include?(" ")

    terms.reject(&:blank?).uniq.sort_by { |term| -term.length }
  end

  def split_search_blocks(text)
    normalized_text = text.to_s.gsub(/\r\n?/, "\n").strip
    return [] if normalized_text.blank?

    paragraphs = normalized_text.split(/\n{2,}/).map(&:strip).reject(&:blank?)

    paragraphs.flat_map do |paragraph|
      next paragraph unless paragraph.length > 500

      paragraph.split(/(?<=[.!?])\s+/).map(&:strip).reject(&:blank?)
    end
  end
end
