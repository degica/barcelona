require 'rails_helper'

describe Service do
  let(:app) { create :app }
  let(:service) { create :web_service, app: app }

  it { expect{service.save}.to_not raise_error }
end
