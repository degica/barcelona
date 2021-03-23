require 'rails_helper'

describe ResourceInstance do
  describe 'associations' do
    it { should belong_to(:resource_class).class_name('ResourceClass') }
  end

  describe 'validations' do
    subject { build(:resource_instance) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end
end
