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
                .includes(:clauses, file_attachment: :blob, package: {})
                .find(params[:id])
    @package = @doc_file.package
    @highlight_query = params[:highlight].to_s.strip
  end

  # CODEX file summary updates
  def summary_search
    @query = params[:q].to_s.strip
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

  def add_doc_file?(uploaded_file)
    @package.doc_files.create(file: uploaded_file).tap do |doc_file|
      @package.errors.merge!(doc_file.errors) unless doc_file.persisted?
    end.persisted?
  end
end
