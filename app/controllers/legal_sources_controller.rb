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
      redirect_to legal_sources_path, notice: "Legal source added."
    else
      render :new, status: :unprocessable_entity
    end
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
