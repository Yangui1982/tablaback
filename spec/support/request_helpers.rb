module RequestHelpers
  def json
    JSON.parse(response.body) rescue {}
  end

  def auth_header(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  def login_and_get_token(email:, password:)
    post "/api/v1/auth/login", params: { email:, password: }

    response.headers["Authorization"]&.split&.last
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
