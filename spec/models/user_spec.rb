require 'rails_helper'

describe User do
  describe '#allowed_to?' do
    it 'returns true if the user has that permission' do
      user = create :user
      perm = create :permission, user: user, key: 'pokemon.train'

      expect(user.allowed_to?('pokemon', 'train')).to eq true
    end

    it 'returns true if user has no permission but is admin' do
      user = create :user
      allow(user).to receive(:admin?) { true }

      expect(user.allowed_to?('pokemon', 'train')).to eq true
    end

    it 'returns false if user does not have the permission' do
      user = create :user

      expect(user.allowed_to?('pokemon', 'train')).to eq false
    end
  end
end
