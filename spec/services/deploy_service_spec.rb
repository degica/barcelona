require 'rails_helper'

describe DeployService, type: :model do
  let(:district) { create :district }
  let(:deployer) { DeployService.new(district) }

  describe '.deploy_service' do
    it 'simply creates a service deployment object' do
      heritage = create :heritage, district: district
      service = create :service, heritage: heritage
      DeployService.deploy_service(service)

      expect(ServiceDeployment.last.service).to eq service
    end
  end

  describe '#check' do
    it 'is backwards compatible' do
      heritage = create :heritage, name: 'sname', district: district
      service = create :service, heritage: heritage

      # if no service deployment object was created
      # it would need to create one

      ds = DeployService.new(district)

      expect(ds).to receive(:notify_completed).with(service)
      allow(ds).to receive(:stack_statuses) {
        {
          'sname' => 'UPDATE_COMPLETE'
        }
      }

      ds.check
    end

    it 'updates state of services' do
      heritage = create :heritage, name: 'sname', district: district
      service = create :service, heritage: heritage
      create :service_deployment, service: service

      ds = DeployService.new(district)

      expect(ds).to receive(:notify_completed).with(service)
      allow(ds).to receive(:stack_statuses) {
        {
          'sname' => 'UPDATE_COMPLETE'
        }
      }

      ds.check
    end

    it 'updates state of services that are not ready yet' do
      heritage = create :heritage, name: 'sname', district: district
      service = create :service, heritage: heritage
      create :service_deployment, service: service

      ds = DeployService.new(district)

      expect(ds).to receive(:notify_incomplete).with(service)
      allow(ds).to receive(:stack_statuses) {
        {
          'sname' => 'UPDATE_IN_PROGRESS'
        }
      }

      ds.check
    end

    it 'update state of services that are failed' do
      heritage = create :heritage, name: 'sname', district: district
      service = create :service, heritage: heritage
      create :service_deployment, service: service

      ds = DeployService.new(district)

      expect(ds).to receive(:notify_failed).with(service)
      allow(ds).to receive(:stack_statuses) {
        {
          'sname' => 'UPDATE_ROLLBACK_COMPLETE'
        }
      }

      ds.check
    end
  end

  describe '#stack_statuses' do
    let(:cfclient) { double('CloudformationClient') }

    it 'updates state of services' do
      heritage1 = create :heritage, name: 'service-1', district: district
      heritage2 = create :heritage, name: 'service-2', district: district

      ds = DeployService.new(district)

      allow(ds).to receive(:cloudformation) { cfclient }

      allow(cfclient).to receive(:list_stacks) do
        [
          double('Response', stack_summaries:[
            double('Summary', {
              stack_name: 'heritage-service-1',
              stack_status: 'UPDATE_COMPLETE'
            }),

            double('Summary', {
              stack_name: 'heritage-service-2',
              stack_status: 'UPDATE_FAILED'
            }),

            double('Summary', {
              stack_name: 'heritage-service-3',
              stack_status: 'UPDATE_IN_PROGRESS'
            })
          ])
        ]
      end

      expect(ds.stack_statuses).to eq({
          'service-1' => 'UPDATE_COMPLETE',
          'service-2' => 'UPDATE_FAILED'
      })
    end
  end

  describe '#notify_completed' do
  end

  describe '#notify_incomplete' do
  end

  describe '#notify_failed' do
  end
end
