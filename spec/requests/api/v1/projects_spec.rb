require "rails_helper"

RSpec.describe "Projects API", type: :request do
  let(:owner)     { create(:user) }
  let(:stranger)  { create(:user) }
  let!(:mine)     { create(:project, user: owner) }
  let!(:not_mine) { create(:project, user: stranger) }

  describe "GET /api/v1/projects" do
    it "ne renvoie que mes projets (policy_scope)" do
      get "/api/v1/projects", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |h| h["id"] }
      expect(ids).to include(mine.id)
      expect(ids).not_to include(not_mine.id)
    end
  end

  describe "GET /api/v1/projects/:id" do
    it "OK sur mon projet" do
      get "/api/v1/projects/#{mine.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
    end

    it "404 sur projet d’autrui (scope.find)" do
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
