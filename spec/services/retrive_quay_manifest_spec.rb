require 'rails_helper'

describe RetrieveQuayManifest do
  let(:heritage) { create :heritage, image_name: "quay.io/degica/barcelona" }
  let(:endpoint) { district.endpoints.create!(name: "load-balancer")}

  describe "retrieve a manifest" do
    let(:heritage) { create :heritage, image_name: "quay.io/degica/barcelona" }
    let(:user) { "user" }
    let(:password) { "test" }
    let(:token) { "testTokenValue" }

    it "it should return correct response" do
      stub_request(:get, "https://quay.io/v2/auth?scope=repository:degica/barcelona:pull&service=quay.io").
      with(
        headers: {
          'Authorization'=>'Basic dXNlcjp0ZXN0',
          'Host'=>'quay.io',
        }).
      to_return(body: {token: token }.to_json)

      body = {
        "schemaVersion": 2,
        "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
        "config": {
           "mediaType": "application/vnd.docker.container.image.v1+json",
           "size": 10987,
           "digest": "test"
        },
        "layers": []
      }

      stub_request(:get, "https://quay.io/v2/degica/barcelona/manifests/1.9.5").
      with(
        headers: {
          'Accept'=>'application/vnd.docker.distribution.manifest.v2+json',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>"Bearer #{token}",
          'Host'=>'quay.io',
          'User-Agent'=>'Ruby'
        }).
      to_return(status: 200, body: body.to_json, headers: {})

      response = RetrieveQuayManifest.new().process(user, password, heritage)
      expect(response.code).to eq "200"
      expect(JSON.parse(response.body)["mediaType"]).to eq "application/vnd.docker.distribution.manifest.v2+json"
    end

    context "when user and password is not correct" do
      it "it should return an error response" do
        error_response = {
          "errors":[
            {
              "code": "UNAUTHORIZED",
              "message": "Could not find robot with specified username"
            }
          ]
        }

        stub_request(:get, "https://quay.io/v2/auth?scope=repository:degica/barcelona:pull&service=quay.io").
        with(
          headers: {
            'Authorization'=>'Basic dXNlcjp0ZXN0',
            'Host'=>'quay.io',
          }).
        to_return(status: 401, body: error_response.to_json)

        response = RetrieveQuayManifest.new().process(user, password, heritage)
        expect(response.code).to eq "401"
        expect(response.body).to eq error_response.to_json
      end
    end

    context "when token is not correct" do
      it "it should return an error response" do
        stub_request(:get, "https://quay.io/v2/auth?scope=repository:degica/barcelona:pull&service=quay.io").
        with(
          headers: {
            'Authorization'=>'Basic dXNlcjp0ZXN0',
            'Host'=>'quay.io',
          }).
        to_return(status: 200, body: {token: token }.to_json)

        error_response = {
          "error": "Signature verification failed"
        }

        stub_request(:get, "https://quay.io/v2/degica/barcelona/manifests/1.9.5").
        with(
          headers: {
            'Accept'=>'application/vnd.docker.distribution.manifest.v2+json',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{token}",
            'Host'=>'quay.io',
            'User-Agent'=>'Ruby'
          }).
        to_return(status: 401, body: error_response.to_json, headers: {})

        response = RetrieveQuayManifest.new().process(user, password, heritage)
        expect(response.code).to eq "401"
        expect(response.body).to eq error_response.to_json
      end
    end

    context "when registry is not quay" do
      let(:heritage) { create :heritage, image_name: "test.io/degica/barcelona" }

      it "it should return an error" do
        quay_manifest = RetrieveQuayManifest.new()
        expect { quay_manifest.process(user, password, heritage) }.to raise_error
      end
    end
  end
end
