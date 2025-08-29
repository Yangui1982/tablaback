module Sortable
  extend ActiveSupport::Concern

  def apply_sort(scope, allowed:, default:, dir_default: "desc")
    col = params[:sort].presence_in(allowed) || default
    dir = params[:dir].to_s.downcase == "asc" ? "asc" : "desc"
    scope.order(Arel.sql("#{col} #{dir}"))
  end
end
