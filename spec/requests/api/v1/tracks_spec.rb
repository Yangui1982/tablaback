require 'rails_helper'

RSpec.describe "API::V1::Tracks", type: :request do
  let(:user) { create(:user) }
  let(:token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }
  let(:headers) do
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end

  let(:project) { create(:project, user: user) }
  let(:score)   { create(:score, project: project) }

  describe "POST /projects/:project_id/scores/:score_id/tracks" do
    it "crée une piste" do
      post api_v1_project_score_tracks_path(project, score),
        params: { track: { name: "Lead Guitar", midi_channel: 1 } }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["name"]).to eq("Lead Guitar")
    end

    it "refuse un doublon de nom" do
      create(:track, score: score, name: "Lead Guitar")
      post api_v1_project_score_tracks_path(project, score),
        params: { track: { name: "Lead Guitar" } }.to_json,
        headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("déjà utilisé")
    end

    it "refuse un doublon de canal MIDI" do
      create(:track, score: score, midi_channel: 2)
      post api_v1_project_score_tracks_path(project, score),
        params: { track: { name: "Rhythm", midi_channel: 2 } }.to_json,
        headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("canal MIDI")
    end
  end

  describe "PATCH /projects/:project_id/scores/:score_id/tracks/:id" do
    let!(:track) { create(:track, score: score, name: "Lead Guitar", midi_channel: 1) }

    it "met à jour la piste" do
      patch api_v1_project_score_track_path(project, score, track),
        params: { track: { name: "Lead Guitar Edited" } }.to_json,
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Lead Guitar Edited")
    end

    it "refuse un doublon de nom à la mise à jour" do
      create(:track, score: score, name: "Rhythm")
      patch api_v1_project_score_track_path(project, score, track),
        params: { track: { name: "Rhythm" } }.to_json,
        headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("déjà utilisé")
    end
  end

  describe "DELETE /projects/:project_id/scores/:score_id/tracks/:id" do
    let!(:track) { create(:track, score: score) }

    it "supprime et décrémente tracks_count" do
      expect {
        delete api_v1_project_score_track_path(project, score, track), headers: headers
      }.to change { score.reload.tracks_count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
