module Support
  module ApiRequest
    def api_request(method, path, params)
      user = create :user
      headers = {
        "X-Barcelona-Token" => user.token,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
      send(method, path, params.to_json, headers)
    end
  end
end

RSpec.configure do |c|
  c.include Support::ApiRequest, type: :request
end
