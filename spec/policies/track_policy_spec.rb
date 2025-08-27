require "rails_helper"

RSpec.describe TrackPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:user)    { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:score)   { create(:score, project: project) }
  let(:own)     { create(:track, score: score) }
  let(:other)   { create(:track) }

  permissions :show?, :create?, :update?, :destroy? do
    it { is_expected.to permit(user, own) }
    it { is_expected.not_to permit(user, other) }
  end

  describe "Scope" do
    it "ne retourne que les tracks liés aux projets de l'utilisateur" do
      scope = Pundit.policy_scope!(user, Track)
      expect(scope).to include(own)
      expect(scope).not_to include(other)
    end
  end
end
