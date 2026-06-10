class LegalSourcesController < ApplicationController
  before_action :require_admin!

  def index
    @legal_sources = LegalSource.with_attached_source_file.recent_first
  end

  def new
    @legal_source = LegalSource.new(default_legal_source_attributes)
  end

  def create
    @legal_source = LegalSource.new(legal_source_params)

    if @legal_source.save
      ImportLegalSourceFromUrl.call(@legal_source)
      redirect_to legal_sources_path, notice: "Legal source added and imported."
    else
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => error
    @legal_source.destroy if @legal_source&.persisted?
    @legal_source ||= LegalSource.new(legal_source_params)
    @legal_source.errors.add(:base, "Import failed: #{error.message}")
    render :new, status: :unprocessable_entity
  end

  def autofill
    uploaded_file = params.require(:source_file)
    metadata = LegalSourceMetadataExtractor.call(uploaded_file)

    render json: { metadata: metadata }
  rescue ActionController::ParameterMissing
    render json: { error: "Choose a file before using autofill." }, status: :unprocessable_entity
  rescue StandardError => error
    Rails.logger.warn("Legal source autofill failed: #{error.class} - #{error.message}")
    render json: { error: "Metadata could not be detected for this file." }, status: :unprocessable_entity
  end

  def destroy
    legal_source = LegalSource.find(params[:id])
    legal_source.destroy

    redirect_to legal_sources_path(remove: true), notice: "Legal source removed."
  end

  private

  def require_admin!
    return if current_user.admin?

    redirect_to root_path, alert: "You do not have access to source management."
  end

  def default_legal_source_attributes
    {
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_format: "pdf"
    }
  end

  def legal_source_params
    params.require(:legal_source).permit(
      :title,
      :citation,
      :jurisdiction,
      :source_type,
      :authority_level,
      :publisher,
      :source_url,
      :source_format,
      :source_file
    )
  end
end
