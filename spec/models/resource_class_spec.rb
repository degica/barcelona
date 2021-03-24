require 'rails_helper'

describe ResourceClass do
  describe 'validations' do
    subject { build(:resource_class) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end

  describe '.build_from_hash' do
    it 'builds a class from a hash' do
      yml = <<~YAML
        Credentials:
          Properties:
            Id:
              type: string
            Password:
              type: string
            Active:
              type: boolean
              default: false
      YAML

      thehash = YAML.load(yml)

      rc = ResourceClass.build_from_hash(thehash)

      expect(rc.save).to eq true
      expect(ResourceClassItem.exists?(name: 'Id')).to eq true
      expect(ResourceClassItem.exists?(name: 'Password')).to eq true
      expect(ResourceClassItem.exists?(name: 'Active')).to eq true

      expect(ResourceClassItem.find_by(name: 'Id').valuetype).to eq 'string'
      expect(ResourceClassItem.find_by(name: 'Password').valuetype).to eq 'string'
      expect(ResourceClassItem.find_by(name: 'Active').valuetype).to eq 'boolean'
      expect(ResourceClassItem.find_by(name: 'Active').default).to eq 'false'
    end
  end

  describe '#destroy' do
    it 'destroys the class items' do
      rci = create(:resource_class_item)

      rci.resource_class.destroy!

      expect(ResourceClassItem.count).to be_zero
    end
  end
end
