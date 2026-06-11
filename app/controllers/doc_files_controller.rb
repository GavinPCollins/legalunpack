# CODEX add document
class DocFilesController < ApplicationController
  def show
    doc_file = current_user_doc_files.find(params[:id])

    render partial: "components/doc_file", locals: { doc_file: doc_file }, layout: false
  end

  def create
    @package = current_user.packages.find(params[:package_id])
    uploaded_files = Array(params[:files]).reject(&:blank?)

    if uploaded_files.any? && uploaded_files.all? { |uploaded_file| add_doc_file?(uploaded_file) }
      ExtractPackageTextJob.perform_later(@package)

      redirect_to @package, notice: "Document added."
    else
      @package.errors.add(:base, "Choose at least 1 file") if uploaded_files.empty?
      render "packages/show", status: :unprocessable_entity
    end
  end

  # CODEX file summary updates
  def summary
    @doc_file = DocFile
                .joins(:package)
                .where(packages: { user_id: current_user.id })
                .includes({ clauses: :flags }, file_attachment: :blob, package: {})
                .find(params[:id])
    @package = @doc_file.package
    @highlight_query = params[:highlight].to_s.strip
    @highlight_clause_id = params[:highlight_clause_id].to_s
  end

  def flags
    @doc_file = DocFile
                .joins(:package)
                .where(packages: { user_id: current_user.id })
                .includes({ clauses: :flags }, file_attachment: :blob, package: {})
                .find(params[:id])
    @package = @doc_file.package
    @clauses = @doc_file.clauses
                        .select { |clause| clause.flags.any? }
                        .sort_by { |clause| [clause.position || Float::INFINITY, clause.id] }
  end

  # CODEX file summary updates
  def summary_search
    @query = params[:q].to_s.strip

    if params[:package_id].present?
      @search_package = current_user.packages.find(params[:package_id])
      @package = package_summary_search_result(@search_package)

      return render partial: "doc_files/package_summary_search_results",
                    locals: { package: @package, search_package: @search_package, query: @query }
    end

    @doc_files = summary_search_results

    render partial: "doc_files/summary_search_results",
           locals: { doc_files: @doc_files, query: @query }
  end

  def destroy
    doc_file = current_user_doc_files.find(params[:id])
    package = doc_file.package
    doc_file.destroy

    redirect_to package, notice: "Document removed."
  end

  def replace
    doc_file = current_user_doc_files.active.find(params[:id])
    uploaded_file = params[:replacement_file]
    return redirect_to(doc_file.package, alert: "Choose a replacement file.") if uploaded_file.blank?

    replacement = replace_doc_file!(doc_file, uploaded_file)
    ExtractPackageTextJob.perform_later(doc_file.package)

    redirect_to doc_file.package, notice: "#{file_name(doc_file)} was replaced with #{file_name(replacement)}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to doc_file.package, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def current_user_doc_files
    DocFile.joins(:package).where(packages: { user_id: current_user.id })
  end

  def summary_search_results
    return DocFile.none if @query.blank?

    doc_files = DocFile
                .joins(:package)
                .where(packages: { user_id: current_user.id })
                .active
                .includes(:package, file_attachment: :blob)

    doc_files = doc_files.where(package_id: params[:package_id]) if params[:package_id].present?

    doc_files.search_by_ai_summary(@query).order(updated_at: :desc)
  end

  def package_summary_search_result(package)
    return nil if @query.blank?

    package = current_user.packages
                          .includes({ clauses: :flags }, doc_files: { file_attachment: :blob })
                          .find(package.id)

    if package.doc_files.active.search_by_ai_summary(@query).exists? || package_clause_matches?(package)
      package
    end
  end

  def package_clause_matches?(package)
    normalized_query = @query.downcase

    package.clauses.any? do |clause|
      next false if clause.doc_file&.archived?

      [ clause.title, clause.risk_level, clause.summary, clause.content ].compact.any? do |value|
        value.downcase.include?(normalized_query)
      end
    end
  end

  def add_doc_file?(uploaded_file)
    @package.doc_files.create(file: uploaded_file).tap do |doc_file|
      @package.errors.merge!(doc_file.errors) unless doc_file.persisted?
    end.persisted?
  end

  def replace_doc_file!(doc_file, uploaded_file)
    replacement = doc_file.package.doc_files.build(file: uploaded_file)

    DocFile.transaction do
      replacement.save!
      resolution_note = "file being replaced with #{file_name(replacement)}"
      resolved_at = Time.current

      Flag.unresolved
          .where(clause_id: doc_file.clause_ids)
          .update_all(
            resolved: true,
            resolved_at: resolved_at,
            resolution_note: resolution_note,
            updated_at: resolved_at
          )

      doc_file.update!(
        archived_at: resolved_at,
        replaced_by_doc_file: replacement
      )
    end

    replacement
  end

  def file_name(doc_file)
    doc_file.file.attached? ? doc_file.file.filename.to_s : "Untitled file"
  end
end
