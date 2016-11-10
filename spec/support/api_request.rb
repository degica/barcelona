module Support
  module ApiRequest
    def api_request(method, path, params={}, headers={})
      default_headers = {
        "X-Barcelona-Token" => user.token,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
      headers = default_headers.merge(headers)
      send(method, path, params: params.to_json, headers: headers)
    end
  end
end

RSpec.configure do |c|
  c.include Support::ApiRequest, type: :request
end
