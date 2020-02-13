require 'rails_helper'

describe ApplicationPolicy do
  let(:user) { create :user }

  subject { ApplicationPolicy.new(user, record) }

  describe 'type operation' do
    let(:record) { instance_double(Class) }
    let(:record_class_name) { "SomeClass" }
    before do
      allow(record).to receive(:name) { record_class_name }
    end

    describe '#create?' do
      context 'for admins' do
        let(:user) { create :user, roles: ["admin"] }
        it { is_expected.to be_create }
      end

      context 'for plebs' do
        it { is_expected.to_not be_create }
      end

      context 'for developers allowed to do so' do
        before do
          create :permission, user: user, key: 'someclass.create'
        end
        it { is_expected.to be_create }
      end

      context 'even if other developers have the permission' do
        before do
          create :permission, key: 'someclass.create'
        end
        it { is_expected.to_not be_create }
      end
    end

    describe '#new?' do
      context 'when #create? returns true' do
        before { allow(subject).to receive(:create?) { true } }
        it { is_expected.to be_new }
      end

      context 'when #create? returns false' do
        before { allow(subject).to receive(:create?) { false } }
        it { is_expected.to_not be_new }
      end
    end

    describe '#index?' do
      context 'for admins' do
        let(:user) { create :user, roles: ["admin"] }
        it { is_expected.to be_index }
      end

      context 'for ordinary users' do
        it { is_expected.to_not be_index }
      end

      context 'for developers allowed to do so' do
        before do
          create :permission, user: user, key: 'someclass.index'
        end
        it { is_expected.to be_index }
      end
    end
  end

  describe 'instance operation' do
    let(:record) { instance_double(Object) }
    let(:record_class_name) { "SomeClass" }
    before do
      class_object = instance_double(Class)
      allow(class_object).to receive(:name) { record_class_name }
      allow(record).to receive(:class) { class_object }
    end

    describe '#meow?' do
      context 'for admins' do
        let(:user) { create :user, roles: ["admin"] }
        it { is_expected.to be_meow }
      end

      context 'for ordinary users' do
        it { is_expected.to_not be_meow }
      end

      context 'for developers allowed to do so' do
        before do
          create :permission, user: user, key: 'someclass.meow'
        end
        it { is_expected.to be_meow }
      end
    end

    describe '#update?' do
      context 'when #edit? returns true' do
        before { allow(subject).to receive(:edit?) { true } }
        it { is_expected.to be_update }
      end

      context 'when #edit? returns false' do
        before { allow(subject).to receive(:edit?) { false } }
        it { is_expected.to_not be_update }
      end
    end
  end
end
