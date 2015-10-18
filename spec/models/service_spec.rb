require 'rails_helper'

describe Service do
  let(:heritage) { create :heritage }
  let(:service) { create :web_service, heritage: heritage }

  it { expect{service.save}.to_not raise_error }
end
