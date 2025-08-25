class Api::V1::ScoresController < ApplicationController
  include ScoreDefaults
  before_action :set_project
  before_action :set_score, only: %i[show update destroy]

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
      render json: { errors: score.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @score.update(score_params)
      render json: @score
    else
      render json: { errors: @score.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @score.destroy!
    head :no_content
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
end
