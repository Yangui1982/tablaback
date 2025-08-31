class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ErrorRendering
  include Pagy::Backend

  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE     = 100

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError do
    render_error("forbidden", "Vous n'êtes pas autorisé à effectuer cette action", status: :forbidden)
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render_error("not_found", e.message, status: :not_found)
  end

  rescue_from ActionController::ParameterMissing do |e|
    render_error("bad_request", e.message, status: :bad_request)
  end

  rescue_from ActiveRecord::RecordNotUnique, with: :handle_unique_constraint

  after_action :verify_authorized,    except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only:   :index, unless: :skip_pundit?

  private
  def render_error(code, payload = nil, status:)
    body = { code: code }

    case payload
    when String
      body[:message] = payload
    when Array
      body[:errors]  = payload
      # Optionnel : fournir aussi un message concaténé si utile aux anciens tests/clients
      body[:message] = payload.join(", ") unless payload.empty?
    when Hash
      body[:details] = payload
    when NilClass
      # rien
    else
      # Type inattendu → on le range dans details pour ne rien perdre
      body[:details] = payload
    end

    # Rétro-compat : certaines specs/clients lisent `error` au lieu de `code`
    body[:error] = code

    render json: body, status: status
  end

  def handle_unique_constraint(exception)
    message =
      if exception.message.include?("index_tracks_on_score_id_and_name")
        "Une piste avec ce nom existe déjà dans ce score."
      elsif exception.message.include?("index_tracks_on_score_id_and_midi_channel_unique")
        "Une piste utilise déjà ce canal MIDI dans ce score."
      else
        "Contrainte d'unicité violée."
      end

    render_error("unique_violation", message, status: :unprocessable_entity)
  end

  def skip_pundit?
    devise_controller? ||
      request.path.start_with?("/rails/") ||
      request.path.start_with?("/sidekiq") ||
      self.class.name.start_with?("ActiveStorage::")
  end

  def pagination_params
    page = params[:page].to_i
    per  = params[:per].to_i
    page = 1 if page <= 0
    per  = DEFAULT_PER_PAGE if per <= 0
    per  = MAX_PER_PAGE if per > MAX_PER_PAGE
    { page:, per: }
  end

  def render_paginated(scope, each_serializer:, root: :data, extra_meta: {})
    @pagy, records = pagy(scope, items: pagination_params[:per], page: pagination_params[:page])

    render json: {
      root => ActiveModelSerializers::SerializableResource.new(records, each_serializer:),
      meta: {
        page:  @pagy.page,
        pages: @pagy.pages,
        count: @pagy.count,
        per:   @pagy.items
      }.merge(extra_meta)
    }
  end
end
