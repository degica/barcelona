require 'rails_helper'

describe "POST /districts/:district/heritages", type: :request do
  let(:user) { create :user }
  let(:district) { create :district }
  let(:endpoint) { create :endpoint, district: district }
  let(:image_name) { "nginx" }
  let(:image_tag) { "latest" }
  let(:endpoint) { create :endpoint, district: district }

  let(:params) do
    {
      version: version,
      name: "nginx",
      image_name: image_name,
      image_tag: image_tag,
      before_deploy: "echo hello",
      scheduled_tasks: [
        {
          schedule: "rate(1 minute)",
          command: "echo hello"
        }
      ],
      environment: [
        {name: "ENV_KEY", ssm_path: "path/to/env_key"},
        {name: "SECRET", value: "raw"}
      ],
      services: [
        {
          name: "web",
          service_type: "web",
          public: true,
          force_ssl: true,
          cpu: 128,
          memory: 256,
          command: "nginx",
          reverse_proxy_image: 'org/custom_revpro:v1.2',
          port_mappings: [
            {container_port: 3333, protocol: "udp", lb_port: 3333 }
          ],
          health_check: {
            protocol: 'tcp',
            port: 1111
          },
          listeners: [{
            endpoint: endpoint.name,
            health_check_path: "/"
          }],
          hosts: [
            {
              hostname: 'awesome-app.degica.com',
              ssl_cert_path: 's3://degica-bucket/path/to/cert',
              ssl_key_path: 's3://degica-bucket/path/to/key'
            }
          ]
        }
      ]
    }
  end

  shared_examples "create" do
    it "creates a heritage" do
      expect(DeployRunnerJob).to receive(:perform_later)
      api_request(:post, "/v1/districts/#{district.name}/heritages", params)
      expect(response.status).to eq 200
      heritage = JSON.load(response.body)["heritage"]
      expect(heritage["version"]).to eq version
      expect(heritage["name"]).to eq "nginx"
      expect(heritage["image_name"]).to eq "nginx"
      expect(heritage["image_tag"]).to eq "latest"
      expect(heritage["before_deploy"]).to eq "echo hello"
      expect(heritage["scheduled_tasks"][0]["schedule"]).to eq "rate(1 minute)"
      expect(heritage["scheduled_tasks"][0]["command"]).to eq "echo hello"
      expect(heritage["services"][0]["name"]).to eq "web"
      expect(heritage["services"][0]["public"]).to eq true
      expect(heritage["services"][0]["cpu"]).to eq 128
      expect(heritage["services"][0]["memory"]).to eq 256
      expect(heritage["services"][0]["command"]).to eq "nginx"
      expect(heritage["services"][0]["force_ssl"]).to eq true
      expect(heritage["services"][0]["reverse_proxy_image"]).to eq "org/custom_revpro:v1.2"

      udp_mapping = heritage["services"][0]["port_mappings"].find do |port_mapping|
        port_mapping["lb_port"]  == 3333
      end
      expect(udp_mapping["host_port"]).to be_a Integer
      expect(udp_mapping["protocol"]).to eq "udp"

      http_mapping = heritage["services"][0]["port_mappings"].find do |port_mapping|
        port_mapping["lb_port"]  == 80
      end
      expect(http_mapping["container_port"]).to eq 3000
      expect(http_mapping["host_port"]).to be_a Integer
      expect(http_mapping["protocol"]).to eq "http"

      https_mapping = heritage["services"][0]["port_mappings"].find do |port_mapping|
        port_mapping["lb_port"]  == 443
      end
      expect(https_mapping["container_port"]).to eq 3000
      expect(https_mapping["host_port"]).to be_a Integer
      expect(https_mapping["protocol"]).to eq "https"

      expect(heritage["services"][0]["health_check"]["protocol"]).to eq "tcp"
      expect(heritage["services"][0]["health_check"]["port"]).to eq 1111
      expect(heritage["services"][0]["hosts"][0]["hostname"]).to eq "awesome-app.degica.com"
      expect(heritage["services"][0]["hosts"][0]["ssl_cert_path"]).to eq "s3://degica-bucket/path/to/cert"
      expect(heritage["services"][0]["hosts"][0]["ssl_key_path"]).to eq "s3://degica-bucket/path/to/key"
    end
  end

  given_auth(GithubAuth) do
    context "when version is 1" do
      let(:version) { 1 }
      it_behaves_like "create"

      it "throw error when heritage name is already used" do
        api_request(:post, "/v1/districts/#{district.name}/heritages", params)

        # create same name heritage
        api_request(:post, "/v1/districts/#{district.name}/heritages", params)
        expect(response.status).to eq 500
        expect(JSON.parse(response.body)["error"]).to eq "heritage name is already used "
      end
    end

    context "when version is 2" do
      let(:version) { 2 }
      it_behaves_like "create"
    end

    context 'when image path is ECR' do
      let(:version) { 1 }
      let(:image_tag) { "latest" }

      context 'when public image' do
        let(:image_name) { "public.ecr.aws/degica/barcelona" }
        it 'check if the public image exits' do
          expect_any_instance_of(EcrService).to receive(:validate_image!)
          api_request(:post, "/v1/districts/#{district.name}/heritages", params)
        end
      end

      context 'when private image' do
        let(:image_name) { "111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/barcelona" }
        it 'check if the public image exits' do
          expect_any_instance_of(EcrService).to receive(:validate_image!)
          api_request(:post, "/v1/districts/#{district.name}/heritages", params)
        end
      end
    end

    context 'when image path is not ECR' do
      let(:version) { 1 }

      it 'do not call EcrService' do
        expect_any_instance_of(EcrService).not_to receive(:validate_image!)
        api_request(:post, "/v1/districts/#{district.name}/heritages", params)
      end
    end

    context "when ssm_path does not exist" do
      let(:version) { 1 }

      it "throw an error" do
        ssm_paths = ["/barcelona/#{district.name}/path/to/env_key"]
        mock_response = Struct.new(:parameters, :invalid_parameters, keyword_init: true)
        expect_any_instance_of(Aws::SSM::Client).to receive(:get_parameters).
          with(names: ssm_paths).and_return(
            mock_response.new(parameters: [], invalid_parameters: ssm_paths)
          )

        api_request(:post, "/v1/districts/#{district.name}/heritages", params)
        expect(response.status).to eq 400
        expect(JSON.parse(response.body)["error"]).to eq "These ssm keys do not exist: [\"/barcelona/#{district.name}/path/to/env_key\"]"
      end
    end

    context "when ssm_path is empty" do
      let(:version) { 1 }

      it "do not throw an error" do
        params.delete(:environment)
        mock_response = Struct.new(:parameters, :invalid_parameters, keyword_init: true)
        expect_any_instance_of(Aws::SSM::Client).not_to receive(:get_parameters)

        api_request(:post, "/v1/districts/#{district.name}/heritages", params)
        expect(response.status).to eq 200
      end
    end

    context "when ssm_paths are more than 10" do
      let(:version) { 1 }

      it "do not throw an error" do
        ssm_paths = []

        (0..11).each do |i|
          ssm_paths << {name: "ENV_KEY", ssm_path: "path/to/env_key#{i}"}
        end
        params[:environment] = ssm_paths
        ssm_paths = ["/barcelona/#{district.name}/path/to/env_key"]
        mock_response = Struct.new(:parameters, :invalid_parameters, keyword_init: true)

        api_request(:post, "/v1/districts/#{district.name}/heritages", params)
        expect(response.status).to eq 200
      end
    end
  end
end
