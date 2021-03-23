require 'rails_helper'

describe ResourceClassItem do
  describe 'associations' do
    it { should belong_to(:resource_class).class_name('ResourceClass') }
  end

  describe 'validations' do
    subject { build(:resource_class_item) }
    it { should validate_presence_of(:name) }
  end
end
