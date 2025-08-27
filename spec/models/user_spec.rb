require 'rails_helper'

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:projects).dependent(:destroy) }

  it "a un email valide et unique" do
    create(:user, email: "a@b.fr")
    user = build(:user, email: "a@b.fr")
    expect(user).not_to be_valid
  end
end
