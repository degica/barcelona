require 'rails_helper'

describe User do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }

  describe '#token' do
    it 'does not save the actual token' do
      create :user, token: 'hello'

      expect(User.last.token).to be_nil
    end
  end

  describe '#find_by_token' do
    it 'finds the correct user' do
      create :user, token: 'correct_user', name: 'correct'
      create :user, token: 'wrong_user', name: 'wrong'

      expect(User.find_by_token('correct_user').name).to eq 'correct'
    end
  end
end
