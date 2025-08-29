require "rails_helper"

RSpec.describe "Projects API", type: :request do
  let(:owner)     { create(:user) }
  let(:stranger)  { create(:user) }
  let!(:mine)     { create(:project, user: owner) }
  let!(:not_mine) { create(:project, user: stranger) }

  it "pagine les résultats" do
    me = create(:user, password: "secret1234")
    create_list(:project, 15, user: me)

    get "/api/v1/projects?page=2&per=5", headers: auth_headers(me, strategy: :login)

    expect(response).to have_http_status(:ok)
    expect(json_data.size).to eq(5)
    expect(json_meta["page"]).to eq(2)
    expect(json_meta["per"]).to eq(5)
    expect(json_meta["pages"]).to eq(3)
    expect(json_meta["count"]).to eq(15)
  end

  describe "GET /api/v1/projects" do
    it "ne renvoie que mes projets (policy_scope)" do
      me    = create(:user, password: "secret1234")
      other = create(:user, password: "secret1234")
      p1 = create(:project, user: me)
      p2 = create(:project, user: me)
      _  = create(:project, user: other)

      get "/api/v1/projects", headers: auth_headers(me, strategy: :login)

      expect(response).to have_http_status(:ok)

      ids = json_data.map { |h| h["id"] }
      expect(ids).to match_array([p1.id, p2.id])

      expect(json_meta.keys).to include("page", "pages", "count", "per")
      expect(json_meta["count"]).to eq(2)
    end
  end

  describe "GET /api/v1/projects/:id" do
    it "OK sur mon projet" do
      get "/api/v1/projects/#{mine.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
    end

    it "404 sur projet d'autrui (scope.find)" do
      get "/api/v1/projects/#{not_mine.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/projects" do
    it "crée un projet (authorize project)" do
      post "/api/v1/projects", params: { project: { title: "New" } }, headers: auth_headers(owner)
      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    it "met à jour mon projet" do
      patch "/api/v1/projects/#{mine.id}", params: { project: { title: "Up" } }, headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
    end

    it "404 si je tente celui d’autrui" do
      patch "/api/v1/projects/#{not_mine.id}", params: { project: { title: "Nope" } }, headers: auth_headers(owner)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/projects/:id" do
    it "supprime mon projet" do
      delete "/api/v1/projects/#{mine.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:no_content)
    end

    it "404 sur projet d’autrui" do
      delete "/api/v1/projects/#{not_mine.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:not_found)
    end
  end
end
