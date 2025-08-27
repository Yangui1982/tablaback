require "rails_helper"

RSpec.describe ProjectPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:user)  { create(:user) }
  let(:own)   { create(:project, user: user) }
  let(:other) { create(:project) }

  permissions :show?, :update?, :destroy? do
    it { is_expected.to permit(user, own) }
    it { is_expected.not_to permit(user, other) }
  end

  permissions :create? do
    it { is_expected.to permit(user, Project.new(user: user)) }
  end

  describe "Scope" do
    it "ne retourne que les projets de l'utilisateur" do
      scope = Pundit.policy_scope!(user, Project)
      expect(scope).to include(own)
      expect(scope).not_to include(other)
    end
  end
end
