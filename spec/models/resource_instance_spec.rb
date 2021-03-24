require 'rails_helper'

describe ResourceInstance do
  describe 'associations' do
    it { should belong_to(:resource_class).class_name('ResourceClass') }
    it { should belong_to(:district).class_name('District') }
  end

  describe 'validations' do
    subject { build(:resource_instance) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    
    it { should validate_presence_of(:resource_class) }
    it { should validate_presence_of(:district) }
  end
end
