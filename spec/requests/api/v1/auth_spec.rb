require 'rails_helper'

RSpec.describe "API::V1::Auth", type: :request do
  let(:user){ create(:user, password: "secret1234") }

  it "login retourne un JWT" do
    post "/api/v1/auth/login", params: { email: user.email, password: "secret1234" }
    expect(response).to have_http_status(:ok)
    expect(response.headers["Authorization"]).to match(/^Bearer /)
  end

  it "logout invalide le token" do
    post "/api/v1/auth/login", params: { email: user.email, password: "secret1234" }
    token = response.headers["Authorization"]
    delete "/api/v1/auth/logout", headers: { "Authorization" => token }
    expect(response).to have_http_status(:no_content)

    get "/api/v1/projects", headers: { "Authorization" => token }
    expect(response).to have_http_status(:unauthorized)
  end
end
