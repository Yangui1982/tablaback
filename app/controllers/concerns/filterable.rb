module Filterable
  extend ActiveSupport::Concern

  def apply_query(scope, on:)
    return scope unless params[:q].present?
    scope.where("#{on} ILIKE ?", "%#{params[:q]}%")
  end
end
