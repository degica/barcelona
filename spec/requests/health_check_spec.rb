require 'rails_helper'

describe "GET /health_check", type: :request do
  it "returns 200" do
    get "/health_check"
    expect(response.status).to eq 200
  end
end
