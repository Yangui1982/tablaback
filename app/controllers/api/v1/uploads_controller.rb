class Api::V1::UploadsController < ApplicationController
  include ScoreDefaults
  before_action :authenticate_user!

  def create
    file = params[:file]
    return render json: { error: 'file_missing' }, status: :bad_request unless file.present?

    project = resolve_project!
    score   = resolve_score!(project)

    score.source_file.attach(file)
    unless score.source_file.attached?
      return render json: { error: 'attach_failed' }, status: :unprocessable_content
    end

    score.update!(
      status: :ready,
      imported_format: infer_format(file),
      doc: score.doc.presence || default_doc(score.title)
    )

    # ImportScoreJob.perform_later(score.id) # sinon commente cette ligne

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

  # --- Résolution Project ---
  # Priorité :
  # 1) project_id (doit appartenir au current_user)
  # 2) project_title => création si non trouvé (on choisit créer pour l’UX)
  # 3) sinon => 400
  def resolve_project!
    if params[:project_id].present?
      current_user.projects.find(params[:project_id])
    elsif params[:project_title].present?
      # on crée toujours un projet (ou tu peux chercher un existant portant ce titre si tu préfères)
      current_user.projects.create!(title: params[:project_title])
    else
      render(json: { error: 'project_missing', detail: 'Passer project_id OU project_title' }, status: :bad_request) and return
    end
  end

  # --- Résolution Score ---
  # Priorité :
  # 1) score_id dans le project (sécurisé par ownership du project)
  # 2) score_title => création
  # 3) sinon => crée un score "Untitled"
  def resolve_score!(project)
    if params[:score_id].present?
      project.scores.find(params[:score_id])
    else
      title = params[:score_title].presence || 'Untitled'
      project.scores.create!(title: title, doc: default_doc(title))
    end
  end

  # Extension → format
  def infer_format(file_param)
    name = if file_param.respond_to?(:original_filename)
      file_param.original_filename.to_s
    else
      file_param.to_s
    end
    ext = File.extname(name).downcase
    return 'guitarpro' if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return 'musicxml'  if %w[.xml .musicxml .mxl].include?(ext)
    'unknown'
  end
end
