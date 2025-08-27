class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: "forbidden" }, status: :forbidden
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: "not_found", message: e.message }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "bad_request", message: e.message }, status: :bad_request
  end

  rescue_from ActiveRecord::RecordNotUnique, with: :handle_unique_constraint

  after_action :verify_authorized,     except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped,  only:   :index, unless: :skip_pundit?

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

  def skip_pundit?
    devise_controller? ||
      request.path.start_with?("/rails/") ||
      request.path.start_with?("/sidekiq") ||
      self.class.name.start_with?("ActiveStorage::")
  end
end
