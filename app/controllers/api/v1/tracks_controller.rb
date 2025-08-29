class Api::V1::TracksController < ApplicationController
  include Sortable
  include Filterable

  before_action :set_project
  before_action :set_score
  before_action :set_track, only: %i[show update destroy]

  def index
    scope = policy_scope(@score.tracks)
    scope = apply_query(scope, on: "name")
    scope = apply_sort(
      scope,
      allowed: %w[created_at updated_at name midi_channel],
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
      data: ActiveModelSerializers::SerializableResource.new(records, each_serializer: TrackSerializer),
      meta: {
        page:  @pagy.page,
        pages: @pagy.pages,
        count: @pagy.count,
        per:   @pagy.items,
        project_id: @project.id,
        score_id:   @score.id
      }
    }
  end

  def show
    authorize @track
    render json: @track
  end

  def create
    @track = @score.tracks.new(track_params)
    authorize @track

    if @track.save
      render json: @track, status: :created
    else
      render_error("validation_error", @track.errors.full_messages, status: :unprocessable_content)
    end
  end

  def update
    authorize @track
    if @track.update(track_params)
      render json: @track
    else
      render_error("validation_error", @track.errors.full_messages, status: :unprocessable_content)
    end
  end

  def destroy
    authorize @track
    @track.destroy!
    head :no_content
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
    authorize @project, :show?
  end

  def set_score
    @score = policy_scope(@project.scores).find(params[:score_id])
    authorize @score, :show?
  end

  def set_track
    @track = policy_scope(@score.tracks).find(params[:id])
  end

  def track_params
    params.require(:track).permit(:name, :instrument, :tuning, :capo, :midi_channel)
  end
end
