require 'rails_helper'

RSpec.describe "JWT denylist", type: :request do
  let(:user) { create(:user, password: "secret1234") }

  it "insère un JTI dans JwtDenylist lors du logout et bloque le token ensuite" do
    post "/api/v1/auth/login", params: { email: user.email, password: "secret1234" }
    token = response.headers["Authorization"]
    expect(token).to be_present

    expect {
      delete "/api/v1/auth/logout", headers: { "Authorization" => token }
    }.to change { JwtDenylist.count }.by(1)

    expect(response).to have_http_status(:no_content)

    get "/api/v1/projects", headers: { "Authorization" => token }
    expect(response).to have_http_status(:unauthorized)
  end
end
