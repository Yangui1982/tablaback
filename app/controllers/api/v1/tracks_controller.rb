class Api::V1::TracksController < ApplicationController
  before_action :set_project
  before_action :set_score
  before_action :set_track, only: [:show, :update, :destroy]

  def index
    tracks = policy_scope(@score.tracks).order(created_at: :desc)
    render json: tracks
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
      render json: { errors: @track.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    authorize @track
    if @track.update(track_params)
      render json: @track
    else
      render json: { errors: @track.errors.full_messages }, status: :unprocessable_content
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
