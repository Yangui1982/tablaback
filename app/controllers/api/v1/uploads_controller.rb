class Api::V1::UploadsController < ApplicationController
  include ScoreDefaults
  before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def create
    file = params.require(:file)

    project = resolve_project!
    return if performed?

    score   = resolve_score!(project)
    return if performed?

    imported_format = infer_format(file)
    if imported_format == "unknown"
      return render_error("unsupported_format", "format de fichier non supporté", status: :unprocessable_content)
    end

    score.source_file.attach(file)
    unless score.source_file.attached?
      return render_error('attach_failed', "échec de l'attachement", status: :unprocessable_content)
    end

    score.update!(
      status: :processing,
      imported_format: imported_format,
      doc: score.doc.presence || default_doc(score.title)
    )

    # --- Correlation ID propagé au job ---
    ImportScoreJob.perform_later(score.id, correlation_id: SecureRandom.hex(6))

    render json: {
      ok: true,
      project_id: project.id,
      score_id:   score.id,
      status:     score.status,
      imported_format: score.imported_format,
      source_url: score.source_file.attached? ? url_for(score.source_file) : nil
    }, status: :created
  end

  private

  def resolve_project!
    if params[:project_id].present?
      current_user.projects.find(params[:project_id])
    elsif params[:project_title].present?
      current_user.projects.create!(title: params[:project_title])
    else
      render(json: { error: 'project_missing', detail: 'projet manquant, passer project_id OU project_title' }, status: :bad_request) and return
    end
  end

  def resolve_score!(project)
    if params[:score_id].present?
      project.scores.find(params[:score_id])
    else
      title = params[:score_title].presence || 'Untitled'
      project.scores.create!(title: title, doc: default_doc(title))
    end
  end

  def infer_format(file_param)
    name = if file_param.respond_to?(:original_filename)
      file_param.original_filename.to_s
    else
      file_param.to_s
    end
    ext = File.extname(name).downcase
    return 'guitarpro' if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return 'mxl' if ext == '.mxl'
    return 'musicxml'  if %w[.xml .musicxml].include?(ext)
    'unknown'
  end
end
