require 'rails_helper'

describe ReviewAppPolicy do
  let(:user) { create :user }
  let(:record) { create :review_app }

  subject { ReviewAppPolicy.new(user, record) }

  describe '#ci_create?' do
    it { is_expected.to be_ci_create }
  end

  describe '#ci_delete?' do
    it { is_expected.to be_ci_delete }
  end
end
