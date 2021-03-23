require 'rails_helper'

describe ResourceInstanceItem do
  describe 'associations' do
    it { should belong_to(:resource_instance).class_name('ResourceInstance') }
    it { should belong_to(:resource_class_item).class_name('ResourceClassItem') }
  end

  describe 'validations' do
    it { should validate_presence_of(:resource_instance) }
    it { should validate_presence_of(:resource_class_item) }
    it { should validate_presence_of(:value) }
  end
end
