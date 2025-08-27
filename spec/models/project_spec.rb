require 'rails_helper'

RSpec.describe Project, type: :model do
  let(:user) { create(:user) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:scores).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }

    it "valide l'unicité du titre pour un même user" do
      create(:project, user: user, title: 'My Tabs')
      dup = build(:project, user: user, title: 'My Tabs')
      expect(dup).not_to be_valid
      expect(dup.errors.details[:title].any? { |e| e[:error] == :taken }).to be true
    end

    it 'autorise le même titre pour un autre user' do
      create(:project, user: user, title: 'Shared Name')
      other_user = create(:user)
      same_title_other_user = build(:project, user: other_user, title: 'Shared Name')
      expect(same_title_other_user).to be_valid
    end
  end

  describe 'dépendances' do
    it 'détruit les partitions associées' do
      project = create(:project, user: user)
      create(:score, project: project)
      expect { project.destroy }.to change { Score.count }.by(-1)
    end
  end
end
