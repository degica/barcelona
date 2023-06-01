require "rails_helper"

describe Barcelona::Network::RDSStack do
  let(:district) { create :district }

  it "generates RDS stack" do
    stack = described_class.new("rds-name", district, engine: :postgresql, db_name: "dbname", db_user: "dbuser")
    generated = JSON.load(stack.target!)

    expect(generated["Parameters"]["DBPassword"]).to be_present
    expect(generated["Resources"]["DBInstance"]).to be_present
    expect(generated["Resources"]["DBInstance"]["Properties"]["Engine"]).to eq "postgres"
    expect(generated["Resources"]["DBInstance"]["Properties"]["MasterUsername"]).to eq "dbuser"
    expect(generated["Resources"]["DBInstance"]["Properties"]["DBName"]).to eq "dbname"
    expect(generated["Resources"]["DBSecurityGroup"]).to be_present
    expect(generated["Resources"]["DBSubnetGroup"]).to be_present
    expect(generated["Outputs"]["DBEndpoint"]).to be_present
  end
end
