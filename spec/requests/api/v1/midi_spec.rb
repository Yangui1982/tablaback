# spec/requests/midi_spec.rb
RSpec.describe "MIDI endpoints", type: :request do
  it "422 sur score vide" do
    user    = create(:user)
    project = create(:project, user: user)
    score   = create(:score, project: project, doc: { "ppq"=>480, "tempo_bpm"=>120, "time_signature"=>[4,4], "tracks"=>[] })

    get midi_api_v1_project_score_path(project, score), headers: api_auth_headers(user, strategy: :login)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["code"]).to eq("empty_score")
  end
end
