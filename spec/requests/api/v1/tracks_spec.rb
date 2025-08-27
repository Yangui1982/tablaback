require "rails_helper"
require "devise/jwt/test_helpers"

RSpec.describe "API::V1::Tracks", type: :request do
  let(:user)  { create(:user) }
  let(:base_headers) { { "Accept" => "application/json" } }

  # JSON (POST/PATCH)
  let(:auth_json_headers) do
    Devise::JWT::TestHelpers.auth_headers(
      base_headers.merge("Content-Type" => "application/json"),
      user
    )
  end

  # non-JSON (GET/DELETE)
  let(:auth_headers) do
    Devise::JWT::TestHelpers.auth_headers(base_headers, user)
  end

  let(:project) { create(:project, user: user) }
  let(:score)   { create(:score, project: project) }

  # Ressources d’un autre utilisateur pour vérifier le scoping Pundit (→ 404)
  let(:stranger)        { create(:user) }
  let(:foreign_project) { create(:project, user: stranger) }
  let(:foreign_score)   { create(:score, project: foreign_project) }
  let!(:foreign_track)  { create(:track, score: foreign_score, name: "Secret", midi_channel: 10) }

  describe "GET /projects/:project_id/scores/:score_id/tracks" do
    before do
      create(:track, score: score, name: "Lead",   midi_channel: 1)
      create(:track, score: score, name: "Rhythm", midi_channel: 2)
    end

    it "liste les pistes (index) du score de l'utilisateur (policy_scope)" do
      get api_v1_project_score_tracks_path(project, score), headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_a(Array)
      expect(body.map { |t| t["name"] }).to include("Lead", "Rhythm")
      # On ne voit pas les tracks d’autrui
      expect(body.map { |t| t["name"] }).not_to include("Secret")
    end

    it "404 si on liste les pistes d’un score appartenant à un autre utilisateur" do
      get api_v1_project_score_tracks_path(foreign_project, foreign_score), headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /projects/:project_id/scores/:score_id/tracks/:id" do
    let!(:track) { create(:track, score: score, name: "Solo", midi_channel: 3) }

    it "retourne une piste (show)" do
      get api_v1_project_score_track_path(project, score, track), headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(track.id)
      expect(body["name"]).to eq("Solo")
      expect(body["midi_channel"]).to eq(3)
    end

    it "404 si on demande une piste d'un autre utilisateur" do
      get api_v1_project_score_track_path(foreign_project, foreign_score, foreign_track), headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /projects/:project_id/scores/:score_id/tracks" do
    it "crée une piste" do
      post api_v1_project_score_tracks_path(project, score),
           params: { track: { name: "Lead Guitar", midi_channel: 1 } }.to_json,
           headers: auth_json_headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["name"]).to eq("Lead Guitar")
    end

    it "404 si je tente de créer une piste sur un score d'autrui" do
      post api_v1_project_score_tracks_path(foreign_project, foreign_score),
           params: { track: { name: "Nope", midi_channel: 1 } }.to_json,
           headers: auth_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "refuse un doublon de nom" do
      create(:track, score: score, name: "Lead Guitar")
      post api_v1_project_score_tracks_path(project, score),
           params: { track: { name: "Lead Guitar" } }.to_json,
           headers: auth_json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("déjà utilisé")
    end

    it "refuse un doublon de canal MIDI" do
      create(:track, score: score, midi_channel: 2)
      post api_v1_project_score_tracks_path(project, score),
           params: { track: { name: "Rhythm", midi_channel: 2 } }.to_json,
           headers: auth_json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("déjà utilisé")
    end

    it "refuse un canal MIDI hors plage (1 / 16)" do
      post api_v1_project_score_tracks_path(project, score),
           params: { track: { name: "Bad0", midi_channel: 0 } }.to_json,
           headers: auth_json_headers
      expect(response).to have_http_status(:unprocessable_content)

      post api_v1_project_score_tracks_path(project, score),
           params: { track: { name: "Bad17", midi_channel: 17 } }.to_json,
           headers: auth_json_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /projects/:project_id/scores/:score_id/tracks/:id" do
    let!(:track) { create(:track, score: score, name: "Lead Guitar", midi_channel: 1) }

    it "met à jour la piste" do
      patch api_v1_project_score_track_path(project, score, track),
            params: { track: { name: "Lead Guitar Edited" } }.to_json,
            headers: auth_json_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Lead Guitar Edited")
    end

    it "404 si je tente de mettre à jour une piste d'autrui" do
      patch api_v1_project_score_track_path(foreign_project, foreign_score, foreign_track),
            params: { track: { name: "Hack" } }.to_json,
            headers: auth_json_headers
      expect(response).to have_http_status(:not_found)
    end

    it "refuse un doublon de nom à la mise à jour" do
      create(:track, score: score, name: "Rhythm")
      patch api_v1_project_score_track_path(project, score, track),
            params: { track: { name: "Rhythm" } }.to_json,
            headers: auth_json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("déjà utilisé")
    end

    it "refuse d'assigner un canal déjà pris" do
      create(:track, score: score, midi_channel: 4, name: "Other")
      patch api_v1_project_score_track_path(project, score, track),
            params: { track: { midi_channel: 4 } }.to_json,
            headers: auth_json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("déjà utilisé")
    end
  end

  describe "DELETE /projects/:project_id/scores/:score_id/tracks/:id" do
    let!(:track) { create(:track, score: score) }

    it "supprime et décrémente tracks_count" do
      expect {
        delete api_v1_project_score_track_path(project, score, track), headers: auth_headers
      }.to change { score.reload.tracks_count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "404 si je tente de supprimer une piste d'autrui" do
      delete api_v1_project_score_track_path(foreign_project, foreign_score, foreign_track), headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "authentification" do
    it "retourne 401 si Authorization manquant" do
      get api_v1_project_score_tracks_path(project, score)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
