class Api::V1::ScoresController < ApplicationController
  include ScoreDefaults
  include Sortable
  include Filterable

  before_action :set_project
  before_action :set_score, only: %i[show update destroy import midi render_midi midi_by_tracks]

  def index
    scope = policy_scope(@project.scores)
    scope = apply_query(scope, on: "title")
    scope = apply_sort(
      scope,
      allowed: %w[created_at updated_at title tempo status tracks_count],
      default: "created_at",
      dir_default: "desc"
    )

    page = params[:page].to_i
    per  = params[:per].to_i
    page = 1   if page <= 0
    per  = 20  if per <= 0
    per  = 100 if per > 100

    @pagy, records = pagy(scope, items: per, page: page)

    render json: {
      data: ActiveModelSerializers::SerializableResource.new(records, each_serializer: ScoreSerializer, with_doc: false),
      meta: {
        page:  @pagy.page,
        pages: @pagy.pages,
        count: @pagy.count,
        per:   @pagy.items,
        project_id: @project.id
      }
    }
  end

  def show
    authorize @score
    render json: @score
  end

  def create
    title  = params.dig(:score, :title) || "Untitled"
    @score = @project.scores.new(score_params.merge(doc: default_doc(title)))
    authorize @score

    if @score.save
      render json: @score, status: :created
    else
      render_error("validation_error", @score.errors.full_messages, status: :unprocessable_content)
    end
  end

  def update
    authorize @score
    if @score.update(score_params)
      render json: @score
    else
      render_error("validation_error", @score.errors.full_messages, status: :unprocessable_content)
    end
  end

  def destroy
    authorize @score
    @score.destroy!
    head :no_content
  end

  # -------- Import (.gp*/.musicxml → job) -----------------------------------

  def import
    authorize @score, :import?

    file = params[:file]
    return render_error("file_missing", "paramètre file manquant", status: :bad_request) unless file.present?

    @score.source_file.attach(file)
    unless @score.source_file.attached?
      return render_error("attach_failed", "échec de l'attache du fichier", status: :unprocessable_content)
    end

    imported_format = infer_format(file)
    if imported_format == "unknown"
      return render_error("unsupported_format", "Format non supporté", status: :unprocessable_content)
    end

    # On stocke le format (pour le job) et on nettoie l'éventuelle erreur précédente
    @score.update!(imported_format: imported_format, import_error: nil)

    # Lance l'import : synchrone en test, async ailleurs
    if Rails.env.test?
      ImportScoreJob.perform_now(@score.id)
    else
      ImportScoreJob.perform_later(@score.id)
    end

    @score.reload
    render json: {
      ok: true,
      status: @score.status,
      imported_format: @score.imported_format,
      midi_attached: @score.export_midi_file.attached?
    }, status: :ok
  end

  # ----------------------------- MIDI ----------------------------------------

  # GET /api/v1/projects/:project_id/scores/:id/midi
  def midi
    authorize @score, :show?
    ensure_midi_up_to_date!
    return head :not_found unless @score.export_midi_file.attached?

    response.headers["Content-Disposition"] = %(inline; filename="#{safe_filename(@score.title)}.mid")
    send_data @score.export_midi_file.download, type: "audio/midi"
  rescue ArgumentError => e
    return render_error("empty_score", "Aucune note à exporter", status: :unprocessable_content) if e.message == "empty_score"
    raise
  end

  # POST /api/v1/projects/:project_id/scores/:id/render_midi
  def render_midi
    authorize @score, :update?
    rebuild_midi!
    render json: { ok: true, midi_url: url_for(@score.export_midi_file) }
  rescue ArgumentError => e
    return render_error("empty_score", "Aucune note à exporter", status: :unprocessable_content) if e.message == "empty_score"
    raise
  end

  # GET /api/v1/projects/:project_id/scores/:id/midi_by_tracks?indexes[]=0&indexes[]=2
  def midi_by_tracks
    authorize @score, :show?
    idxs = Array(params[:indexes]).map { |x| Integer(x) rescue nil }.compact.uniq
    return render_error("bad_request", "indexes[] requis (entiers >= 0)", status: :bad_request) if idxs.empty?

    data = MidiRenderService.new(
      doc: @score.doc,
      title: "#{@score.title} (subset)",
      track_indexes: idxs
    ).call

    send_data data,
              filename: "#{safe_filename(@score.title)}-subset.mid",
              type: "audio/midi",
              disposition: "inline"
  rescue ArgumentError => e
    return render_error("empty_score", "Les pistes demandées ne contiennent aucune note", status: :unprocessable_content) if e.message == "empty_score"
    raise
  end

  # ---------------------------------------------------------------------------

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
    authorize @project, :show?
  end

  def set_score
    @score = policy_scope(@project.scores).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("not_found", "Score introuvable", status: :not_found)
  end

  def score_params
    params.require(:score).permit(:title, :tempo, :status, :imported_format, :key_sig, :time_sig, doc: {})
  end

  def infer_format(file_param)
    ext = File.extname(file_param.original_filename).downcase
    return "guitarpro" if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return "musicxml"  if %w[.xml .musicxml .mxl].include?(ext)
    "unknown"
  end

  # --- Helpers MIDI ----------------------------------------------------------

  def ensure_midi_up_to_date!
    return if @score.midi_up_to_date?
    rebuild_midi!
  end

  def rebuild_midi!
    data = MidiRenderService.new(doc: @score.doc, title: @score.title).call
    @score.attach_midi!(data, filename: "#{safe_filename(@score.title)}.mid")
  end

  def safe_filename(name)
    (name.presence || "score").parameterize
  end
end
