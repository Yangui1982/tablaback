class Api::V1::ScoresController < ApplicationController
  include ScoreDefaults
  include Sortable
  include Filterable

  before_action :set_project
  before_action :set_score, only: %i[show update destroy import]

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
      data: ActiveModelSerializers::SerializableResource.new(records, each_serializer: ScoreSerializer),
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
      render_error("validation_error", @score.errors.full_messages, status: :unprocessable_entity)
    end
  end

  def update
    authorize @score
    if @score.update(score_params)
      render json: @score
    else
      render_error("validation_error", @score.errors.full_messages, status: :unprocessable_entity)
    end
  end

  def destroy
    authorize @score
    @score.destroy!
    head :no_content
  end

  def import
    authorize @score, :import?

    file = params[:file]
    return render_error("file_missing", "paramètre file manquant", status: :bad_request) unless file.present?

    @score.source_file.attach(file)
    unless @score.source_file.attached?
      return render_error("attach_failed", "échec de l'attache du fichier", status: :unprocessable_entity)
    end

    @score.update!(
      status: :ready,
      imported_format: infer_format(file),
      doc: @score.doc.presence || default_doc(@score.title)
    )

    render json: { ok: true, status: @score.status }
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
    authorize @project, :show?
  end

  def set_score
    @score = policy_scope(@project.scores).find(params[:id])
  end

  def score_params
    params.require(:score).permit(:title, :tempo, :status, :imported_format, :key_sig, :time_sig, doc: {})
  end

  def infer_format(file_param)
    ext = File.extname(file_param.original_filename).downcase
    return "guitarpro" if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return "musicxml"  if %w[.xml .musicxml].include?(ext)
    "unknown"
  end
end
