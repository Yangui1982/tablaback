module AuthHelpers
  def jwt_for(user, aud: nil)
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, aud)
    token
  end

  def api_auth_headers(user, strategy: :direct, password: "secret1234")
    case strategy
    when :login
      post "/api/v1/auth/login",
           params: { email: user.email, password: password },
           as: :json
      expect(response).to have_http_status(:ok)
      token = response.headers["Authorization"] || response.headers["authorization"]
      raise "No Authorization header in login response" if token.nil? || token.empty?
      { "Authorization" => token }
    else
      { "Authorization" => "Bearer #{jwt_for(user)}" }
    end
  end

  def auth_headers(user = nil, **opts)
    raise ArgumentError, "auth_headers(user, ...): user is required" if user.nil?
    api_auth_headers(user, **opts)
  end

  def login_as(user, password: "secret1234")
    api_auth_headers(user, strategy: :login, password: password)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
