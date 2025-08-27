class Api::V1::TracksController < ApplicationController
  before_action :set_project
  before_action :set_score
  before_action :set_track, only: [:show, :update, :destroy]

  def index
    render json: @score.tracks.order(created_at: :desc)
  end

  def show
    render json: @track
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
  rescue ActiveRecord::RecordNotUnique => e
    msg =
      if e.message.include?('index_tracks_on_score_id_and_name')
        "Le nom de piste est déjà utilisé dans cette partition"
      elsif e.message.include?('index_tracks_on_score_id_and_midi_channel_unique')
        "Le canal MIDI est déjà utilisé dans cette partition"
      else
        "Contrainte d'unicité violée"
      end
    render json: { errors: [msg] }, status: :unprocessable_entity
  end

  def destroy
    @track.destroy!
    head :no_content
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_score
    @score = @project.scores.find(params[:score_id])
  end

  def set_track
    @track = @score.tracks.find(params[:id])
  end

  def track_params
    params.require(:track).permit(:name, :instrument, :tuning, :capo, :midi_channel)
  end
end
