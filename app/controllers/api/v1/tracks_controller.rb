class Api::V1::TracksController < ApplicationController
  before_action :set_score
  before_action :set_track, only: %i[update destroy]

  def index
    render json: @score.tracks.order(created_at: :asc)
  end

  def create
    track = @score.tracks.new(track_params)
    if track.save
      render json: track, status: :created
    else
      render json: { errors: track.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @track.update(track_params)
      render json: @track
    else
      render json: { errors: @track.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @track.destroy!
    head :no_content
  end

  private
  def set_score
    @score = current_user.projects.find(params[:project_id]).scores.find(params[:score_id])
  end

  def set_track
    @track = @score.tracks.find(params[:id])
  end

  def track_params
    params.require(:track).permit(:name, :instrument, :tuning, :capo, :channel)
  end
end
