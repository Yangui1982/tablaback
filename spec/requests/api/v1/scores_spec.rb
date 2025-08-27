require 'rails_helper'
require 'devise/jwt/test_helpers'


RSpec.describe "API::V1::Scores", type: :request do
  let(:user)  { create(:user) }
  let(:token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  let(:base_headers) { { 'Accept' => 'application/json' } }

  let(:auth_json_headers) do
    Devise::JWT::TestHelpers.auth_headers(
      base_headers.merge('Content-Type' => 'application/json'),
      user
    )
  end

  let(:auth_headers) do
    Devise::JWT::TestHelpers.auth_headers(base_headers, user)
  end

  let(:project) { create(:project, user: user) }
  let!(:score)  { create(:score, project: project, title: "Etude") }

  describe "auth obligatoire" do
    it "refuse sans token" do
      get api_v1_project_scores_path(project)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "index / show / create / update / destroy" do
    it "liste les scores du projet" do
      create(:score, project: project, title: "Autre")
      get api_v1_project_scores_path(project), headers: auth_json_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_a(Array)
      expect(body.map { |s| s["title"] }).to include("Etude", "Autre")
    end

    it "montre un score" do
      get api_v1_project_score_path(project, score), headers: auth_json_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(score.id)
      expect(body["title"]).to eq("Etude")
    end

    it "crée un score" do
      post api_v1_project_scores_path(project),
        params: { score: { title: "New Score" } }.to_json,
        headers: auth_json_headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["title"]).to eq("New Score")
    end

    it "met à jour un score" do
      patch api_v1_project_score_path(project, score),
        params: { score: { title: "Edited" } }.to_json,
        headers: auth_json_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["title"]).to eq("Edited")
    end

    it "supprime un score" do
      s = create(:score, project: project, title: "Temp")
      delete api_v1_project_score_path(project, s), headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect { s.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "import (upload de fichier)" do
    it "attache un .gp3 et passe le score en ready" do
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
  end
end
