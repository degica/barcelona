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

  module ApiRequestExampleMethods
    def given_auth(auth_class, &block)
      context "given #{auth_class} authentication" do
        before do
          allow_any_instance_of(ApplicationController).to receive(:auth_backend_class) { auth_class }
        end

        instance_eval(&block)
      end
    end
  end
end

RSpec.configure do |c|
  c.include Support::ApiRequest, type: :request
  c.extend Support::ApiRequestExampleMethods, type: :request
end
