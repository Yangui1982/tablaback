class ApplicationController < ActionController::API
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotUnique, with: :handle_unique_constraint

  private

  def handle_unique_constraint(exception)
    message =
      if exception.message.include?('index_tracks_on_score_id_and_name')
        "Une piste avec ce nom existe déjà dans ce score."
      elsif exception.message.include?('index_tracks_on_score_id_and_midi_channel_unique')
        "Une piste utilise déjà ce canal MIDI dans ce score."
      else
        "Contrainte d'unicité violée."
      end

    render json: { error: message }, status: :unprocessable_content
  end
end
