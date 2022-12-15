require 'rails_helper'

describe ServiceDeployment do

  it { should validate_presence_of :service }

  describe 'both completed and failed true' do
    it 'will not be valid' do
      sd = build :service_deployment, completed_at: DateTime.now, failed_at: DateTime.now
      expect(sd).to_not be_valid
    end
  end

  describe '#completed?' do
    it 'returns true if completed' do
      sd = create :service_deployment, completed_at: DateTime.now
      expect(sd).to be_completed
    end

    it 'returns false if not completed' do
      sd = create :service_deployment, completed_at: nil
      expect(sd).to_not be_completed
    end
  end

  describe '#failed?' do
    it 'returns true if failed' do
      sd = create :service_deployment, failed_at: DateTime.now
      expect(sd).to be_failed
    end

    it 'returns false if not failed' do
      sd = create :service_deployment, failed_at: nil
      expect(sd).to_not be_failed
    end
  end

  describe '#finished?' do
    it 'returns true if completed' do
      sd = create :service_deployment, completed_at: DateTime.now
      expect(sd).to be_finished
    end

    it 'returns true if failed' do
      sd = create :service_deployment, failed_at: DateTime.now
      expect(sd).to be_finished
    end

    it 'returns false if not failed or completed' do
      sd = create :service_deployment, failed_at: nil, completed_at: nil
      expect(sd).to_not be_finished
    end
  end

  let(:example_time) { Time.zone.local(2004, 11, 24, 01, 04, 44) }
  describe 'fail!' do
    it 'sets failed' do
      sd = create :service_deployment
      expect(sd).to_not be_failed
      sd.fail!
      expect(sd).to be_failed
    end

    it 'sets failed_at to current time' do
      travel_to example_time do
        sd = create :service_deployment
        expect(sd.failed_at).to be_nil
        sd.fail!
        expect(sd.failed_at).to eq example_time
      end
    end
  end

  describe 'complete!' do
    it 'sets completed' do
      sd = create :service_deployment
      expect(sd).to_not be_completed
      sd.complete!
      expect(sd).to be_completed
    end

    it 'sets completed_at to current time' do
      travel_to example_time do
        sd = create :service_deployment
        expect(sd.completed_at).to be_nil
        sd.complete!
        expect(sd.completed_at).to eq example_time
      end
    end
  end

  describe '.unfinished' do
    it 'returns unfinished deployments' do
      sd1 = create :service_deployment, completed_at: nil
      sd2 = create :service_deployment, completed_at: DateTime.now

      expect(ServiceDeployment.unfinished).to eq [sd1]
    end
  end
end
