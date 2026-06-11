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

  def current_user_doc_files
    DocFile.joins(:package).where(packages: { user_id: current_user.id })
  end

  def render_success(flag, render_context)
    return render_flag_footer(flag, render_context) if note_update_only?
    return render_package_flags(flag) if render_context == "package_group_item"
    return render_file_flags(flag) if render_context == "file_group_item"

    partial =
      case render_context
      when "icon_trigger" then "components/flag_icon_trigger"
      when "group_item" then "components/flag_group_item"
      else "components/flag"
      end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(flag), partial: partial, locals: { flag: flag })
      end
      format.html { redirect_back fallback_location: package_path(flag.clause.package), notice: "Flag updated." }
    end
  end

  def render_file_flags(flag)
    doc_file = current_user_doc_files
               .includes({ clauses: :flags }, file_attachment: :blob)
               .find(flag.clause.doc_file_id)
    file_title = doc_file.file.attached? ? doc_file.file.filename.to_s : "Untitled file"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "file-active-flags",
          partial: "doc_files/active_flags",
          locals: { doc_file: doc_file, file_title: file_title }
        )
      end
      format.html { redirect_to flags_doc_file_path(doc_file), notice: "Flag updated." }
    end
  end

  def render_flag_footer(flag, render_context)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(flag, :footer),
          partial: "components/flag_footer",
          locals: { flag: flag, render_context: render_context, note_open: true }
        )
      end
      format.html { redirect_back fallback_location: package_path(flag.clause.package), notice: "Flag updated." }
    end
  end

  def note_update_only?
    flag_param_keys = params.fetch(:flag, {}).keys

    flag_param_keys == [ "note" ]
  end

  def render_package_flags(flag)
    package = current_user.packages
                          .includes(
                            { clauses: [ :flags, { doc_file: { file_attachment: :blob } } ] },
                            doc_files: [{ clauses: :flags }, { file_attachment: :blob }]
                          )
                          .find(flag.clause.package_id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "package-active-flags",
          partial: "packages/active_flags",
          locals: { package: package }
        )
      end
      format.html { redirect_to package_path(package), notice: "Flag updated." }
    end
  end

  def flag_params
    params.require(:flag).permit(:note, :resolved, :resolution_note)
  end
end
