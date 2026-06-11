require "set"
require "yaml"

namespace :legal_sources do
  desc "Discover local legal source files and add missing entries to config/legal_sources.yml"
  task discover: :environment do
    source_list_path = legal_source_list_path
    source_directory = Rails.root.join(ENV.fetch("DIR", "data/legal_sources"))
    source_list = YAML.safe_load_file(source_list_path, aliases: false) || []
    existing_paths = source_list.filter_map { |attributes| attributes["source_path"] }.to_set
    discovered_entries = []

    unless source_directory.directory?
      puts "Legal source directory does not exist: #{source_directory}"
      next
    end

    source_directory.glob("**/*").sort.each do |path|
      next unless path.file?
      next unless discoverable_format(path)

      relative_path = path.relative_path_from(Rails.root).to_s
      next if existing_paths.include?(relative_path)

      discovered_entries << discovered_entry_for(path, relative_path)
    end

    if discovered_entries.blank?
      puts "No new legal source files discovered."
      next
    end

    updated_source_list = source_list + discovered_entries
    File.write(source_list_path, legal_sources_yaml(updated_source_list))

    discovered_entries.each do |entry|
      puts "Discovered #{entry['title']} (#{entry['source_path']})"
    end
  end

  desc "Create or update legal source records from config/legal_sources.yml"
  task sync: :environment do
    source_list_path = legal_source_list_path
    source_list = YAML.safe_load_file(source_list_path, aliases: false) || []

    if source_list.blank?
      puts "No legal sources found in #{source_list_path}."
      next
    end

    source_list.each do |attributes|
      attributes = attributes.stringify_keys
      source_url = source_url_for(attributes)

      unless source_url
        puts "Skipping #{attributes['title'].presence || '(untitled)'}: source_url or source_path is required"
        next
      end

      legal_source = LegalSource.find_or_initialize_by(source_url: source_url)
      legal_source.assign_attributes(
        title: attributes.fetch("title"),
        citation: attributes["citation"],
        jurisdiction: attributes.fetch("jurisdiction"),
        source_type: attributes.fetch("source_type"),
        authority_level: attributes.fetch("authority_level"),
        publisher: attributes["publisher"],
        source_format: attributes.fetch("source_format")
      )
      legal_source.save!

      puts "#{legal_source.previously_new_record? ? 'Created' : 'Updated'} #{legal_source.title}"
    end
  end

  desc "Delete legal source records that are no longer listed in config/legal_sources.yml"
  task prune: :environment do
    source_list_path = legal_source_list_path
    source_list = YAML.safe_load_file(source_list_path, aliases: false) || []
    configured_urls = source_list.filter_map { |attributes| source_url_for_prune(attributes.stringify_keys) }
    stale_sources = LegalSource.where.not(source_url: configured_urls)

    if stale_sources.none?
      puts "No stale legal sources found."
      next
    end

    stale_sources.find_each do |legal_source|
      puts "Pruning #{legal_source.title}"
      legal_source.destroy!
    end
  end

  desc "Remove local source_path entries from config/legal_sources.yml when their files no longer exist"
  task clean_missing: :environment do
    source_list_path = legal_source_list_path
    source_list = YAML.safe_load_file(source_list_path, aliases: false) || []
    kept_sources, missing_sources = source_list.partition do |attributes|
      source_file_present_or_not_local?(attributes.stringify_keys)
    end

    if missing_sources.blank?
      puts "No missing legal source files found."
      next
    end

    File.write(source_list_path, legal_sources_yaml(kept_sources))

    missing_sources.each do |attributes|
      puts "Removed #{attributes['title'].presence || attributes['source_path']}"
    end
  end

  desc "Import legal source text and chunks from trusted source URLs"
  task import: :environment do
    scope = LegalSource.all
    scope = scope.where(id: ENV["ID"]) if ENV["ID"].present?
    scope = scope.where(imported_at: nil) if ENV["PENDING_ONLY"].present?

    if scope.none?
      puts "No legal sources found to import."
      next
    end

    scope.find_each do |legal_source|
      print "Importing #{legal_source.title}... "
      ImportLegalSourceFromUrl.call(legal_source)
      puts "#{legal_source.legal_source_chunks.count} chunks"
    rescue StandardError => error
      puts "failed: #{error.message}"
    end
  end

  def source_url_for(attributes)
    attributes["source_url"].presence || local_source_url(attributes["source_path"])
  end

  def legal_source_list_path
    path = Pathname.new(ENV.fetch("LEGAL_SOURCES_YML", "config/legal_sources.yml"))
    path.absolute? ? path : Rails.root.join(path)
  end

  def source_url_for_prune(attributes)
    return attributes["source_url"] if attributes["source_url"].present?
    return if attributes["source_path"].blank?

    path = Rails.root.join(attributes["source_path"])
    return path.to_s if path.exist?

    puts "Ignoring missing catalogue file during prune: #{attributes['source_path']}"
    nil
  end

  def source_file_present_or_not_local?(attributes)
    return true if attributes["source_url"].present?
    return true if attributes["source_path"].blank?

    Rails.root.join(attributes["source_path"]).exist?
  end

  def local_source_url(source_path)
    return if source_path.blank?

    path = Rails.root.join(source_path)
    raise "Local legal source file does not exist: #{source_path}" unless path.exist?

    path.to_s
  end

  def discoverable_format(path)
    case path.extname.downcase
    when ".pdf"
      "pdf"
    when ".txt"
      "txt"
    when ".htm", ".html"
      "html"
    end
  end

  def discovered_entry_for(path, relative_path)
    {
      "title" => path.basename(path.extname).to_s.tr("-_", " ").squish.titleize,
      "jurisdiction" => ENV.fetch("JURISDICTION", "VIC"),
      "source_type" => ENV.fetch("SOURCE_TYPE", "regulator_guidance"),
      "authority_level" => ENV.fetch("AUTHORITY_LEVEL", "guidance"),
      "publisher" => ENV.fetch("PUBLISHER", "Consumer Affairs Victoria"),
      "source_path" => relative_path,
      "source_format" => discoverable_format(path)
    }
  end

  def legal_sources_yaml(source_list)
    header = <<~HEADER
      # Trusted legal sources for backend import.
      #
      # Keep this file as the curated source list. Run:
      #   bin/rails legal_sources:discover
      #   bin/rails legal_sources:sync
      #   bin/rails legal_sources:import PENDING_ONLY=1
      #
      # Use source_url for website/PDF URLs. Use source_path for local files under data/legal_sources.

    HEADER

    "#{header}#{source_list.to_yaml.sub(/\\A---\\n/, '')}"
  end
end
