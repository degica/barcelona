require 'rails_helper'

describe BuildHeritage do
  let(:params) do
    {
      name: "heritage",
      image_name: "docker_image",
      image_tag: "latest",
      services: [
        {
          name: "web",
          cpu: 128,
          memory: 128,
          command: "rails s",
          public: true,
          port_mappings: [
            {
              lb_port: 80,
              container_port: 3000
            }
          ],
          listeners: [
            {
              endpoint: endpoint.name,
              health_check_interval: 5,
              health_check_path: "/health_check",
              rule_priority: 99,
              rule_conditions: [
                {
                  type: 'path_pattern',
                  value: '/app*'
                }
              ]
            }
          ]
        },
        {
          name: "worker",
          command: "rake jobs:work"
        }
      ]
    }
  end
  let(:district) { create :district }
  let(:heritage) { BuildHeritage.new(params, district: district).execute }
  let(:endpoint) { district.endpoints.create!(name: "load-balancer")}

  describe "new object" do
    subject { heritage }
    its(:district) { is_expected.to eq district }
    its(:name) { is_expected.to eq 'heritage' }
    its(:image_name) { is_expected.to eq 'docker_image' }
    its(:image_tag) { is_expected.to eq 'latest' }
  end

  describe "create object" do
    before do
      heritage.save!
    end

    it "has 2 services" do
      expect(heritage.services.count).to eq 2

      service1 = heritage.services.first
      expect(service1.id).to be_present
      expect(service1.name).to eq "web"
      expect(service1.cpu).to eq 128
      expect(service1.memory).to eq 128
      expect(service1.command).to eq "rails s"
      expect(service1.public).to eq true
      expect(service1.port_mappings.count).to eq 1
      expect(service1.port_mappings.first.lb_port).to eq 80
      expect(service1.port_mappings.first.container_port).to eq 3000
      expect(service1.listeners.count).to eq 1
      expect(service1.listeners.first.health_check_interval).to eq 5
      expect(service1.listeners.first.health_check_path).to eq "/health_check"
      expect(service1.listeners.first.rule_priority).to eq 99
      expect(service1.listeners.first.rule_conditions).to eq [{"type" => 'path_pattern',
                                                               "value" => '/app*'}]
      expect(service1.listeners.first.endpoint).to eq endpoint

      service2 = heritage.services.second
      expect(service2.name).to eq "worker"
      expect(service2.cpu).to eq 512
      expect(service2.memory).to eq 512
      expect(service2.command).to eq "rake jobs:work"
      expect(service2.port_mappings.count).to eq 0
    end
  end

  describe "update object" do
    before do
      heritage.save!
    end

    context "with name" do
      before do
        new_params = params.dup
        new_params[:image_tag] = "branch"
        new_params[:services][0][:command] = "rails s -b 0.0.0.0"
        new_params[:services][1][:command] = "rake jobs:offwork"
        @updated_heritage = BuildHeritage.new(new_params, district: nil).execute
        @updated_heritage.save!
      end

      it "updates the heritage and associated records" do
        expect(@updated_heritage.services.count).to eq 2
        expect(@updated_heritage.image_tag).to eq "branch"

        service1 = @updated_heritage.services.first
        expect(service1.id).to be_present
        expect(service1.name).to eq "web"
        expect(service1.cpu).to eq 128
        expect(service1.memory).to eq 128
        expect(service1.command).to eq "rails s -b 0.0.0.0"
        expect(service1.public).to eq true
        expect(service1.port_mappings.count).to eq 1
        expect(service1.port_mappings.first.lb_port).to eq 80
        expect(service1.port_mappings.first.container_port).to eq 3000
        expect(service1.listeners.count).to eq 1
        expect(service1.listeners.first.health_check_interval).to eq 5
        expect(service1.listeners.first.health_check_path).to eq "/health_check"
        expect(service1.listeners.first.endpoint.name).to eq endpoint.name

        service2 = @updated_heritage.services.second
        expect(service2.name).to eq "worker"
        expect(service2.cpu).to eq 512
        expect(service2.memory).to eq 512
        expect(service2.command).to eq "rake jobs:offwork"
        expect(service2.port_mappings.count).to eq 0
      end
    end

    context "without name but id" do
      before do
        new_params = params.dup
        new_params[:id] = new_params.delete(:name)
        new_params[:image_tag] = "branch"
        new_params[:services][0][:command] = "rails s -b 0.0.0.0"
        new_params[:services][1][:command] = "rake jobs:offwork"
        @updated_heritage = BuildHeritage.new(new_params, district: nil).execute
        @updated_heritage.save!
      end

      it "updates the heritage and associated records" do
        expect(@updated_heritage.services.count).to eq 2
        expect(@updated_heritage.image_tag).to eq "branch"

        service1 = @updated_heritage.services.first
        expect(service1.id).to be_present
        expect(service1.name).to eq "web"
        expect(service1.cpu).to eq 128
        expect(service1.memory).to eq 128
        expect(service1.command).to eq "rails s -b 0.0.0.0"
        expect(service1.public).to eq true
        expect(service1.port_mappings.count).to eq 1
        expect(service1.port_mappings.first.lb_port).to eq 80
        expect(service1.port_mappings.first.container_port).to eq 3000

        service2 = @updated_heritage.services.second
        expect(service2.name).to eq "worker"
        expect(service2.cpu).to eq 512
        expect(service2.memory).to eq 512
        expect(service2.command).to eq "rake jobs:offwork"
        expect(service2.port_mappings.count).to eq 0
      end
    end

    context "deleting services" do
      before do
        new_params = params.dup
        new_params[:services].delete_at 1
        @updated_heritage = BuildHeritage.new(new_params, district: nil).execute
        @updated_heritage.save!
      end

      it "deletes a service that is not specified in params" do
        expect(@updated_heritage.services.count).to eq 1

        service1 = @updated_heritage.services.first
        expect(service1.id).to be_present
        expect(service1.name).to eq "web"
        expect(service1.cpu).to eq 128
        expect(service1.memory).to eq 128
        expect(service1.command).to eq "rails s"
        expect(service1.public).to eq true
        expect(service1.port_mappings.count).to eq 1
        expect(service1.port_mappings.first.lb_port).to eq 80
        expect(service1.port_mappings.first.container_port).to eq 3000
      end
    end

    context "adding services" do
      before do
        new_params = params.dup
        new_params[:services] << {
          name: "another-service",
          command: "command"
        }
        @updated_heritage = BuildHeritage.new(new_params, district: nil).execute
        @updated_heritage.save!
      end

      it "adds a service" do
        expect(@updated_heritage.services.count).to eq 3

        service1 = @updated_heritage.services.first
        expect(service1.id).to be_present
        expect(service1.name).to eq "web"
        expect(service1.cpu).to eq 128
        expect(service1.memory).to eq 128
        expect(service1.command).to eq "rails s"
        expect(service1.public).to eq true
        expect(service1.port_mappings.count).to eq 1
        expect(service1.port_mappings.first.lb_port).to eq 80
        expect(service1.port_mappings.first.container_port).to eq 3000

        service2 = @updated_heritage.services.second
        expect(service2.name).to eq "worker"
        expect(service2.cpu).to eq 512
        expect(service2.memory).to eq 512
        expect(service2.command).to eq "rake jobs:work"
        expect(service2.port_mappings.count).to eq 0

        service3 = @updated_heritage.services.third
        expect(service3.name).to eq "another-service"
        expect(service3.command).to eq "command"
      end
    end

    context "changing endpoints" do
      let(:endpoint2) { district.endpoints.create!(name: "load-balancer2") }
      before do
        new_params = params.dup
        new_params[:services][0][:listeners][0] = {endpoint: endpoint2.name}
        @updated_heritage = BuildHeritage.new(new_params).execute
        @updated_heritage.save!
      end

      it "updates listners" do
        service1 = @updated_heritage.services.first
        expect(service1).to be_present
        expect(service1.listeners.count).to eq 1
        expect(service1.listeners.first.health_check_interval).to eq 10
        expect(service1.listeners.first.health_check_path).to eq "/"
        expect(service1.listeners.first.endpoint.name).to eq endpoint2.name
      end
    end

    context "deleting listeners" do
      context "when listeners is nil" do
        before do
          new_params = params.dup
          new_params[:services][0].delete :listeners
          @updated_heritage = BuildHeritage.new(new_params).execute
          @updated_heritage.save!
        end

        it "deletes listners" do
          service1 = @updated_heritage.services.first
          expect(service1).to be_present
          expect(service1.listeners.count).to eq 0
        end
      end

      context "when listeners is nil" do
        before do
          new_params = params.dup
          new_params[:services][0][:listeners] = []
          @updated_heritage = BuildHeritage.new(new_params).execute
          @updated_heritage.save!
        end

        it "deletes listners" do
          service1 = @updated_heritage.services.first
          expect(service1).to be_present
          expect(service1.listeners.count).to eq 0
        end
      end
    end
  end
end
