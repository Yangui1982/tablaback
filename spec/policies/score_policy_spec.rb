require "rails_helper"

RSpec.describe ScorePolicy, type: :policy do
  subject(:policy) { described_class }

  let(:user)   { create(:user) }
  let(:project){ create(:project, user: user) }
  let(:own)    { create(:score, project: project) }
  let(:other)  { create(:score) }

  permissions :show?, :create?, :update?, :destroy?, :import?, :export? do
    it { is_expected.to permit(user, own) }
    it { is_expected.not_to permit(user, other) }
  end

  describe "Scope" do
    it "ne retourne que les scores de projets appartenant à l'utilisateur" do
      scope = Pundit.policy_scope!(user, Score)
      expect(scope).to include(own)
      expect(scope).not_to include(other)
    end
  end
end
