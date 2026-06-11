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

  private

  def current_user_doc_files
    DocFile.joins(:package).where(packages: { user_id: current_user.id })
  end

  def summary_search_results
    return DocFile.none if @query.blank?

    doc_files = DocFile
                .joins(:package)
                .where(packages: { user_id: current_user.id })
                .includes(:package, file_attachment: :blob)

    doc_files = doc_files.where(package_id: params[:package_id]) if params[:package_id].present?

    doc_files.search_by_ai_summary(@query).order(updated_at: :desc)
  end

  def package_summary_search_result(package)
    return nil if @query.blank?

    package = current_user.packages
                          .includes({ clauses: :flags }, doc_files: { file_attachment: :blob })
                          .find(package.id)

    if current_user.packages
                   .where(id: package.id)
                   .search_by_ai_summary_and_clauses(@query)
                   .exists?
      package
    end
  end

  def add_doc_file?(uploaded_file)
    @package.doc_files.create(file: uploaded_file).tap do |doc_file|
      @package.errors.merge!(doc_file.errors) unless doc_file.persisted?
    end.persisted?
  end
end
