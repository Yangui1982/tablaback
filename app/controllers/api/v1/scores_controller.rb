class Api::V1::ScoresController < ApplicationController
  include ScoreDefaults
  before_action :set_project
  before_action :set_score, only: %i[show update destroy import]

  def index
    render json: @project.scores.order(created_at: :desc)
  end

  def show
    render json: @score
  end

  def create
    title = params.dig(:score, :title) || "Untitled"
    score = @project.scores.new(score_params.merge(doc: default_doc(title)))
    if score.save
      render json: score, status: :created
    else
      render json: { errors: score.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    if @score.update(score_params)
      render json: @score
    else
      render json: { errors: @score.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    @score.destroy!
    head :no_content
  end

  def import
    return render(json: { error: 'file_missing' }, status: :bad_request) unless params[:file].present?

    @score.source_file.attach(params[:file])
    unless @score.source_file.attached?
      return render(json: { error: 'attach_failed' }, status: :unprocessable_content)
    end
    @score.update!(
      status: :ready,
      imported_format: infer_format(params[:file]),
      doc: @score.doc.presence || default_doc(@score.title)
    )

    render json: { ok: true, status: @score.status }
  end

  private
  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_score
    @score = @project.scores.find(params[:id])
  end

  def score_params
    params.require(:score).permit(:title, :tempo, :status, :imported_format, :key_sig, :time_sig, doc: {})
  end

  def infer_format(file_param)
    ext = File.extname(file_param.original_filename).downcase
    return 'guitarpro' if %w[.gp3 .gp4 .gp5 .gpx .gp].include?(ext)
    return 'musicxml'  if %w[.xml .musicxml].include?(ext)
    'unknown'
  end
end
