# spec/requests/api/v1/uploads_spec.rb
require 'rails_helper'

RSpec.describe "API::V1::Uploads", type: :request do
  let(:user)    { create(:user) }
  let(:auth) do
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    { "Authorization" => "Bearer #{token}" }
  end

  let(:project) { create(:project, user: user) }
  let(:score)   { create(:score, project: project) }

  # On utilise désormais une fixture MXL (format canon)
  let(:mxl_file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/la-mer-trenetlasry.mxl"),
      "application/vnd.recordare.musicxml"
    )
  end

  let(:bad_file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/dummy.txt"),
      "text/plain"
    )
  end

  it "400 si file manquant" do
    post "/api/v1/uploads", params: { project_id: project.id, score_id: score.id }, headers: auth
    expect(response).to have_http_status(:bad_request)
  end

  it "404 si project inexistant" do
    post "/api/v1/uploads",
         params: { project_id: 999_999, score_id: score.id, file: mxl_file },
         headers: auth
    expect(response).to have_http_status(:not_found)
  end

  it "404 si score inexistant" do
    post "/api/v1/uploads",
         params: { project_id: project.id, score_id: 999_999, file: mxl_file },
         headers: auth
    expect(response).to have_http_status(:not_found)
  end

  it "422 si type interdit" do
    post "/api/v1/uploads",
         params: { project_id: project.id, score_id: score.id, file: bad_file },
         headers: auth

    expect(response).to(have_http_status(:unprocessable_content))
  end

  it "crée un score dans un projet existant" do
    post "/api/v1/uploads",
         params: { project_id: project.id, score_title: "New Score", file: mxl_file },
         headers: auth

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["project_id"]).to eq(project.id)
    expect(body["score_id"]).to be_present
    # Le job tourne en asynchrone → status = processing à la création
    expect(body["status"]).to eq("processing")
  end

  it "crée un projet + score à la volée" do
    post "/api/v1/uploads",
         params: { project_title: "Beatles Covers", score_title: "Let It Be", file: mxl_file },
         headers: auth

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["project_id"]).to be_present
    expect(body["score_id"]).to be_present
    # idem : processing immédiatement après l'upload
    expect(body["status"]).to eq("processing")
  end
end
