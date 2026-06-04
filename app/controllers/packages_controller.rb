class PackagesController < ApplicationController
  def index
    # CODEX search function updates
    @query = params[:q].to_s.strip
    @packages = package_search_results
  end

  def show
    @package = current_user.packages.includes(doc_files: { file_attachment: :blob }).find(params[:id])
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
  rescue ActiveRecord::RecordInvalid => error
    add_child_record_errors(error.record)

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
end
