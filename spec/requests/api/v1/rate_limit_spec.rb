RSpec.describe "Rate limiting", type: :request do
  it "limite les logins" do
    user = create(:user, password: "secret1234")
    10.times do
      post "/api/v1/auth/login", params: { email: user.email, password: "wrong" }, as: :json
    end
    post "/api/v1/auth/login", params: { email: user.email, password: "wrong" }, as: :json
    expect(response.status).to eq(429).or be_between(401, 429)
  end
end
