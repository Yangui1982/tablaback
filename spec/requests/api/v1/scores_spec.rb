require "rails_helper"
require "devise/jwt/test_helpers"

RSpec.describe "API::V1::Scores", type: :request do
  let(:user)         { create(:user) }
  let(:base_headers) { { "Accept" => "application/json" } }

  let(:jwt_json_headers) do
    Devise::JWT::TestHelpers.auth_headers(
      base_headers.merge("Content-Type" => "application/json"),
      user
    )
  end

  let(:jwt_headers) do
    Devise::JWT::TestHelpers.auth_headers(base_headers, user)
  end

  let(:project) { create(:project, user: user) }
  let!(:score)  { create(:score, project: project, title: "Etude") }

  let(:stranger)        { create(:user) }
  let(:foreign_project) { create(:project, user: stranger) }
  let!(:foreign_score)  { create(:score, project: foreign_project, title: "Secret") }

  describe "auth obligatoire" do
    it "refuse sans token" do
      get api_v1_project_scores_path(project)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "index / show / create / update / destroy" do
    it "liste les scores du projet (policy_scope)" do
      me      = create(:user, password: "secret1234")
      project = create(:project, user: me)
      s1      = create(:score, project: project)
      s2      = create(:score, project: project)
      _other  = create(:score)

      headers_for_me = Devise::JWT::TestHelpers.auth_headers(base_headers, me)

      get "/api/v1/projects/#{project.id}/scores", headers: headers_for_me
      expect(response).to have_http_status(:ok)

      ids = json_data.map { |h| h["id"] }
      expect(ids).to match_array([s1.id, s2.id])

      expect(json_meta["project_id"]).to eq(project.id)
      expect(json_meta.keys).to include("page", "pages", "count", "per")
      expect(json_meta["count"]).to eq(2)
    end

    it "renvoie 404 si je liste les scores d'un projet qui n'est pas à moi" do
      get api_v1_project_scores_path(foreign_project), headers: jwt_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "montre un score" do
      get api_v1_project_score_path(project, score), headers: jwt_json_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(score.id)
      expect(body["title"]).to eq("Etude")
    end

    it "404 si je tente de montrer un score d'autrui" do
      get api_v1_project_score_path(foreign_project, foreign_score), headers: jwt_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "crée un score" do
      post api_v1_project_scores_path(project),
           params: { score: { title: "New Score" } }.to_json,
           headers: jwt_json_headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["title"]).to eq("New Score")
    end

    it "404 si j'essaie de créer un score sous un projet d'autrui" do
      post api_v1_project_scores_path(foreign_project),
           params: { score: { title: "Nope" } }.to_json,
           headers: jwt_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "met à jour un score" do
      patch api_v1_project_score_path(project, score),
            params: { score: { title: "Edited" } }.to_json,
            headers: jwt_json_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["title"]).to eq("Edited")
    end

    it "404 si je tente de mettre à jour un score d'autrui" do
      patch api_v1_project_score_path(foreign_project, foreign_score),
            params: { score: { title: "Hack" } }.to_json,
            headers: jwt_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "supprime un score" do
      s = create(:score, project: project, title: "Temp")
      delete api_v1_project_score_path(project, s), headers: jwt_headers
      expect(response).to have_http_status(:no_content)
      expect { s.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "404 si je tente de supprimer un score d'autrui" do
      delete api_v1_project_score_path(foreign_project, foreign_score), headers: jwt_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "import (upload de fichier)" do
    it "attache un .gp3 et passe le score en ready (autorisé)" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/dummy.gp3"),
        "application/octet-stream"
      )

      post import_api_v1_project_score_path(project, score),
           params: { file: file },
           headers: jwt_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include("ok" => true, "status" => "ready")
    end

    it "404 si j'essaie d'importer un fichier sur le score d'autrui" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/dummy.gp3"),
        "application/octet-stream"
      )

      post import_api_v1_project_score_path(foreign_project, foreign_score),
           params: { file: file },
           headers: jwt_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
