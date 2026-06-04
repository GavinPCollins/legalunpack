# CODEX add document
class DocFilesController < ApplicationController
  def create
    @package = current_user.packages.find(params[:package_id])
    uploaded_files = Array(params[:files]).reject(&:blank?)

    if uploaded_files.any? && uploaded_files.all? { |uploaded_file| add_doc_file?(uploaded_file) }
      redirect_to @package, notice: "Document added."
    else
      @package.errors.add(:base, "Choose at least 1 file") if uploaded_files.empty?
      render "packages/show", status: :unprocessable_entity
    end
  end

  def destroy
    doc_file = DocFile.joins(:package).where(packages: { user_id: current_user.id }).find(params[:id])
    package = doc_file.package
    doc_file.destroy

    redirect_to package, notice: "Document removed."
  end

  private

  def add_doc_file?(uploaded_file)
    @package.doc_files.create(file: uploaded_file).tap do |doc_file|
      @package.errors.merge!(doc_file.errors) unless doc_file.persisted?
    end.persisted?
  end
end
