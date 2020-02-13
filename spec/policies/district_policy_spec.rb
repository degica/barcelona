require 'rails_helper'

describe DistrictPolicy do
  let(:user) { create :user }
  let(:record) { create :district, name: 'sagrada' }

  subject { DistrictPolicy.new(user, record) }

  describe '#meow?' do
    context 'for admins' do
      let(:user) { create :user, roles: ["admin"] }
      it { is_expected.to be_meow }
    end

    context 'for developers allowed to meow on sagrada' do
      before do
        create :permission, user: user, key: 'district.meow.sagrada'
      end
      it { is_expected.to be_meow }
    end

    context 'for developers allowed to woof on sagrada' do
      before do
        create :permission, user: user, key: 'district.woof.sagrada'
      end
      it { is_expected.to_not be_meow }
    end

    context 'for developers allowed to meow on centro' do
      before do
        create :permission, user: user, key: 'district.meow.centro'
      end
      it { is_expected.to_not be_meow }
    end

    context 'even if other developers have the permission' do
      before do
        create :permission, key: 'district.meow.sagrada'
      end
      it { is_expected.to_not be_meow }
    end
  end
end
