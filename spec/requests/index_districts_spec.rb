require 'rails_helper'

describe "GET /districts", type: :request do
  let(:user) { create :user }
  let(:auth) { {"X-Barcelona-Token" => user.token} }
  let(:district) { create :district }

  it "lists districts" do
    get "/districts/#{district.name}", nil, auth
    expect(response.status).to eq 200
  end
end
