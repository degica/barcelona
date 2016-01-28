require 'rails_helper'

describe ContainerInstance do
  let(:user) { create :user, public_key: 'abc' }
  let(:district) { create :district, users: [user] }
  describe "#instance_user_data" do
    it "generates user data" do
      ci = ContainerInstance.new(district, instance_type: "t2.micro", eip_allocation_id: "alloc")
      user_data = Base64.decode64(ci.instance_user_data)
      expect(user_data).to be_a String
    end
  end
end
