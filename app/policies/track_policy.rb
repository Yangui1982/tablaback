class TrackPolicy < ApplicationPolicy
  def show?    = owner?
  def create?  = owner?
  def update?  = owner?
  def destroy? = owner?
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Tracks dont le Score appartient à un Project du user
      scope.joins(score: :project).where(projects: { user_id: user.id })
    end
  end

  private

  def owner?
    record.score.project.user_id == user.id
  end

end
