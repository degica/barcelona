require 'rails_helper'

describe ResourceClassItem do
  describe 'associations' do
    it { should belong_to(:resource_class).class_name('ResourceClass') }
  end

  describe 'validations' do
    subject { build(:resource_class_item) }
    it { should validate_presence_of(:name) }

    it 'allows boolean type' do
      a = build :resource_class_item, valuetype: 'boolean'
      expect(a).to be_valid
    end

    it 'allows boolean to default to true' do
      a = build :resource_class_item, valuetype: 'boolean', default: 'true'
      expect(a).to be_valid
    end

    it 'allows boolean to default to false' do
      a = build :resource_class_item, valuetype: 'boolean', default: 'false'
      expect(a).to be_valid
    end

    it 'disallows boolean to default to anything else' do
      a = build :resource_class_item, valuetype: 'boolean', default: 'meow'
      expect(a).to_not be_valid
    end

    it 'allows string type' do
      a = build :resource_class_item, valuetype: 'string'
      expect(a).to be_valid
    end

    it 'allows string to default to a string' do
      a = build :resource_class_item, valuetype: 'string', default: 'meow'
      expect(a).to be_valid
    end

    it 'allows integer type' do
      a = build :resource_class_item, valuetype: 'integer'
      expect(a).to be_valid
    end

    it 'allows integer to default to an integer' do
      a = build :resource_class_item, valuetype: 'integer', default: '123'
      expect(a).to be_valid
    end

    it 'disallows integer to default to non integers' do
      a = build :resource_class_item, valuetype: 'integer', default: 'asd'
      expect(a).to_not be_valid
    end

    it 'allows resource class' do
      create :resource_class, name: 'Thing'

      a = build :resource_class_item, valuetype: 'Thing'
      expect(a).to be_valid
    end

    it 'disallows resource class to have a default' do
      create :resource_class, name: 'Thing'

      a = build :resource_class_item, valuetype: 'Thing', default: 'thing'
      expect(a).to_not be_valid
    end

    it 'disallows other types' do
      a = build :resource_class_item, valuetype: 'meow'
      expect(a).to_not be_valid
    end
  end

  describe '#optional?' do
    it 'is true if it has a default' do
      a = build :resource_class_item, valuetype: 'integer', default: 5
      expect(a).to be_optional
    end

    it 'is false without a default' do
      a = build :resource_class_item, valuetype: 'integer'
      expect(a).to_not be_optional
    end
  end
end
