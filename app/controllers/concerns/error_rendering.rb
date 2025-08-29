# app/controllers/concerns/error_rendering.rb
module ErrorRendering
  # Format d’erreur unique pour toute l’API
  # render_error("not_found", "resource_not_found", status: :not_found, meta: { id: 123 })
  def render_error(code, detail, status: :unprocessable_entity, meta: {})
    render json: { error: { code:, detail:, meta: } }, status:
  end
end
