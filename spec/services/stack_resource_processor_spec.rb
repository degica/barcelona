require "rails_helper"

describe StackResourceProcessor do
  it "extracts raw script correctly" do
    script = <<~SCRIPT
      SecGroup: 
        type: AWS::EC2::SecurityGroup
        group_description: Some Security group
        security_group_egress:
          - CidrIp: 127.0.0.1/32
            IpProtocol: -1
        vpc_id: "{{ constant(Barcelona::VpcId) }}"
    SCRIPT

    sds = StackResourceProcessor.new(script, {})

    expect(sds.raw_script).to eq({
      "SecGroup"=>{
        "type"=>"AWS::EC2::SecurityGroup",
        "group_description"=>"Some Security group",
        "security_group_egress"=>[
          {"CidrIp"=>"127.0.0.1/32", "IpProtocol"=>-1}
        ],
        "vpc_id"=>"{{ constant(Barcelona::VpcId) }}"
      }
    })
  end

  it "lists inputs in inputs" do
    # security
    script = <<~SCRIPT
      Name:
        type: Barcelona::Input::String
      Something:
        type: AWS::Foo::Something
        name: "{{ Name }}"
    SCRIPT

    sds = StackResourceProcessor.new(script, {})

    expect(sds.input_names).to eq(["Name"])
    expect(sds.input_type("Name")).to eq(String)
    expect(sds.input_valid?("Name", "hello")).to eq true
  end
end
