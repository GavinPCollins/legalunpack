require "yaml"

namespace :legal_sources do
  desc "Create or update legal source records from config/legal_sources.yml"
  task sync: :environment do
    source_list_path = Rails.root.join("config/legal_sources.yml")
    source_list = YAML.safe_load_file(source_list_path, aliases: false) || []

    if source_list.blank?
      puts "No legal sources found in #{source_list_path}."
      next
    end

    source_list.each do |attributes|
      attributes = attributes.stringify_keys
      source_url = attributes["source_url"].presence || local_source_url(attributes["source_path"])

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

  def local_source_url(source_path)
    return if source_path.blank?

    path = Rails.root.join(source_path)
    raise "Local legal source file does not exist: #{source_path}" unless path.exist?

    path.to_s
  end
end
