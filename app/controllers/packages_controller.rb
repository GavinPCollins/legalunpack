class PackagesController < ApplicationController
  def index
    # CODEX search function updates
    @query = params[:q].to_s.strip
    @packages = package_search_results
  end

  def show
    @package = current_user.packages
                           .includes(
                             { clauses: [ :flags, { doc_file: { file_attachment: :blob } } ] },
                             doc_files: [
                               { clauses: :flags },
                               { file_attachment: :blob },
                               { replaced_by_doc_file: { file_attachment: :blob } }
                             ]
                           )
                           .find(params[:id])
    enqueue_text_extraction_if_needed(@package)
  end

  def analysis
    @package = current_user.packages
                           .includes(
                             { clauses: [ :flags, { doc_file: { file_attachment: :blob } } ] },
                             doc_files: [{ clauses: :flags }, { file_attachment: :blob }]
                           )
                           .find(params[:id])
  end

  def new
    @package = Package.new
  end

  def create # rubocop:disable Metrics/MethodLength
    @package = current_user.packages.build(package_params)
    @package.valid?

    @package.errors.add(:base, "Must contain at least 1 file") unless uploaded_files_present?

    return render :new, status: :unprocessable_entity if @package.errors.any?

    ActiveRecord::Base.transaction do
      @package.save!
      attach_uploaded_files(@package)
      attach_pasted_text(@package)
    end

    # ENQUEUE TEXT EXTRACTION
    ExtractPackageTextJob.perform_later(@package)

    redirect_to @package, notice: "Package created."
  rescue ActiveRecord::RecordInvalid => e
    add_child_record_errors(e.record)

    render :new, status: :unprocessable_entity
  end

  def edit
    @package = current_user.packages.find(params[:id])
  end

  def update
    @package = current_user.packages.find(params[:id])

    if @package.update(package_params)
      redirect_to @package, notice: "Package updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @package = current_user.packages.find(params[:id])
    @package.destroy

    redirect_to packages_path, notice: "Package deleted."
  end

  def analyze
    @package = current_user.packages.find(params[:id])

    files_to_analyze = @package.doc_files.active.where.not(ai_status: "complete").order(:created_at, :id).to_a
    total_files = files_to_analyze.size

    files_to_analyze.each.with_index(1) do |doc_file, position|
      initial_stage =
        if position == 1
          doc_file.extraction_status == "complete" && doc_file.extracted_text.present? ? "analyzing_clauses" : "extracting_text"
        else
          "waiting"
        end

      doc_file.update!(
        ai_status: "processing",
        ai_error: nil,
        analysis_stage: initial_stage,
        analysis_position: position,
        analysis_total: total_files
      )
    end
    AnalyzePackageFilesJob.perform_later(@package)

    redirect_to @package, notice: "AI analysis started."
  end

  private

  def package_params
    params.fetch(:package, {}).permit(:name, :category, :overview, :status)
  end

  # CODEX search function updates
  def package_search_results
    return Package.none if @query.blank?

    current_user.packages
                .search_by_name_and_filename(@query)
                .includes(doc_files: { file_attachment: :blob })
                .order(created_at: :desc)
  end

  def uploaded_files_present?
    Array(params[:files]).reject(&:blank?).any? || params[:pasted_text].present?
  end

  def attach_uploaded_files(package)
    Array(params[:files]).reject(&:blank?).each do |uploaded_file|
      package.doc_files.create!(file: uploaded_file)
    end
  end

  def attach_pasted_text(package)
    return if params[:pasted_text].blank?

    package.doc_files.create!(
      file: {
        io: StringIO.new(params[:pasted_text]),
        filename: "pasted-text.txt",
        content_type: "text/plain"
      }
    )
  end

  def add_child_record_errors(record)
    return unless record.respond_to?(:errors)

    record.errors.full_messages.each do |message|
      @package.errors.add(:base, message)
    end
  end

  def enqueue_text_extraction_if_needed(package)
    return unless package.doc_files.active.needs_text_extraction.exists?

    ExtractPackageTextJob.perform_later(package)
  end
end
