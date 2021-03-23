require 'rails_helper'

describe ResourceClass do
  describe 'validations' do
    subject { build(:resource_class) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end
end
