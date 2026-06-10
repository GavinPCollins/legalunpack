class FlagsController < ApplicationController
  include ActionView::RecordIdentifier

  def update
    flag = current_user_flags.find(params[:id])

    if flag.update(flag_params)
      render_success(flag, params[:render_context])
    else
      redirect_back fallback_location: package_path(flag.clause.package), alert: flag.errors.full_messages.to_sentence
    end
  end

  private

  def current_user_flags
    Flag.joins(clause: :package).where(packages: { user_id: current_user.id })
  end

  def render_success(flag, render_context)
    partial = render_context == "icon_trigger" ? "components/flag_icon_trigger" : "components/flag"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(flag), partial: partial, locals: { flag: flag })
      end
      format.html { redirect_back fallback_location: package_path(flag.clause.package), notice: "Flag updated." }
    end
  end

  def flag_params
    permitted_params = params.require(:flag).permit(:resolved, :resolution_note)
    if ActiveModel::Type::Boolean.new.cast(permitted_params[:resolved]) && permitted_params[:resolution_note].blank?
      permitted_params[:resolution_note] = "No notes added"
    end

    permitted_params
  end
end
