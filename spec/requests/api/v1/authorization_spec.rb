require 'rails_helper'

RSpec.describe "API authorization boundaries", type: :request do
  let(:me)   { create(:user) }
  let(:them) { create(:user) }

  let(:my_headers) do
    token = Warden::JWTAuth::UserEncoder.new.call(me, :user, nil).first
    { "Authorization" => "Bearer #{token}" }
  end

  it "empêche d’accéder au projet d’un autre utilisateur (show)" do
    other_project = create(:project, user: them)

    get api_v1_project_path(other_project), headers: my_headers

    expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
  end

  it "empêche d’accéder à un score d’un autre utilisateur (show)" do
    other_project = create(:project, user: them)
    other_score   = create(:score, project: other_project)

    get api_v1_project_score_path(other_project, other_score), headers: my_headers

    expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
  end

  it "empêche de lister les scores d’un projet qui ne nous appartient pas (index)" do
    other_project = create(:project, user: them)

    get api_v1_project_scores_path(other_project), headers: my_headers

    expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
  end
end
