class ProjectPolicy < ApplicationPolicy
  def show?    = record.user_id == user.id
  def create?  = true
  def update?  = record.user_id == user.id
  def destroy? = record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(user_id: user.id)
  end
end
