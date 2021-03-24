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

  it 'should not be valid without any optional fields filled' do
    rc = build :resource_class, name: 'Employee'
    namefield = build :resource_class_item, name: 'Name', valuetype: 'string'
    agefield = build :resource_class_item, name: 'Age', valuetype: 'integer'
    rc.resource_class_items << namefield
    rc.resource_class_items << agefield
    rc.save!

    ri = build :resource_instance, resource_class: rc

    expect(ri).to_not be_valid
  end

  it 'should not be valid without all optional fields filled' do
    rc = build :resource_class, name: 'Employee'
    namefield = build :resource_class_item, name: 'Name', valuetype: 'string'
    agefield = build :resource_class_item, name: 'Age', valuetype: 'integer'
    rc.resource_class_items << namefield
    rc.resource_class_items << agefield
    rc.save!

    ri = build :resource_instance, resource_class: rc
    ri.resource_instance_items << build(:resource_instance_item, resource_class_item: namefield, value: 'John Smith')

    expect(ri).to_not be_valid
  end

  it 'should be valid when all optional fields are filled' do
    rc = build :resource_class, name: 'Employee'
    namefield = build :resource_class_item, name: 'Name', valuetype: 'string'
    agefield = build :resource_class_item, name: 'Age', valuetype: 'integer'
    rc.resource_class_items << namefield
    rc.resource_class_items << agefield
    rc.save!

    ri = build :resource_instance, resource_class: rc
    ri.resource_instance_items << build(:resource_instance_item, resource_class_item: namefield, value: 'John Smith')
    ri.resource_instance_items << build(:resource_instance_item, resource_class_item: agefield, value: '69')

    expect(ri).to be_valid
  end

  it 'should not be valid with a bad field' do
    rc = build :resource_class, name: 'Employee'
    namefield = build :resource_class_item, name: 'Name', valuetype: 'string'
    agefield = build :resource_class_item, name: 'Age', valuetype: 'integer'
    rc.resource_class_items << namefield
    rc.resource_class_items << agefield
    rc.save!

    rc2 = build :resource_class, name: 'Employee2'
    agefield2 = build :resource_class_item, name: 'Age', valuetype: 'integer'
    rc2.resource_class_items << agefield2
    rc2.save!

    ri = build :resource_instance, resource_class: rc
    ri.resource_instance_items << build(:resource_instance_item, resource_class_item: namefield, value: 'John Smith')
    ri.resource_instance_items << build(:resource_instance_item, resource_class_item: agefield2, value: '69')

    expect(ri).to_not be_valid
  end

end
