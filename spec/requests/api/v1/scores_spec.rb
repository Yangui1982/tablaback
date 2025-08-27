require "rails_helper"
require "devise/jwt/test_helpers"

RSpec.describe "API::V1::Scores", type: :request do
  let(:user)  { create(:user) }
  let(:base_headers) { { "Accept" => "application/json" } }

  let(:auth_json_headers) do
    Devise::JWT::TestHelpers.auth_headers(
      base_headers.merge("Content-Type" => "application/json"),
      user
    )
  end

  let(:auth_headers) do
    Devise::JWT::TestHelpers.auth_headers(base_headers, user)
  end

  let(:project) { create(:project, user: user) }
  let!(:score)  { create(:score, project: project, title: "Etude") }

  # Ressources d’un autre utilisateur pour tester le scoping Pundit
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
      create(:score, project: project, title: "Autre")
      get api_v1_project_scores_path(project), headers: auth_json_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_a(Array)
      expect(body.map { |s| s["title"] }).to include("Etude", "Autre")
      # Vérifie qu’on ne voit pas les scores d’autrui
      titles = body.map { |s| s["title"] }
      expect(titles).not_to include("Secret")
    end

    it "renvoie 404 si je liste les scores d'un projet qui n'est pas à moi" do
      get api_v1_project_scores_path(foreign_project), headers: auth_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "montre un score" do
      get api_v1_project_score_path(project, score), headers: auth_json_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(score.id)
      expect(body["title"]).to eq("Etude")
    end

    it "404 si je tente de montrer un score d'autrui" do
      get api_v1_project_score_path(foreign_project, foreign_score), headers: auth_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "crée un score" do
      post api_v1_project_scores_path(project),
           params: { score: { title: "New Score" } }.to_json,
           headers: auth_json_headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["title"]).to eq("New Score")
    end

    it "404 si j'essaie de créer un score sous un projet d'autrui" do
      post api_v1_project_scores_path(foreign_project),
           params: { score: { title: "Nope" } }.to_json,
           headers: auth_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "met à jour un score" do
      patch api_v1_project_score_path(project, score),
            params: { score: { title: "Edited" } }.to_json,
            headers: auth_json_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["title"]).to eq("Edited")
    end

    it "404 si je tente de mettre à jour un score d'autrui" do
      patch api_v1_project_score_path(foreign_project, foreign_score),
            params: { score: { title: "Hack" } }.to_json,
            headers: auth_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "supprime un score" do
      s = create(:score, project: project, title: "Temp")
      delete api_v1_project_score_path(project, s), headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect { s.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "404 si je tente de supprimer un score d'autrui" do
      delete api_v1_project_score_path(foreign_project, foreign_score), headers: auth_headers
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
           headers: auth_headers

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
           headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
