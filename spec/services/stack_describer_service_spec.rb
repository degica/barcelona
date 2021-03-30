require "rails_helper"

describe StackDescriberService do
  it "outputs a simple hash" do
    sds = StackDescriberService.new('{}', {})
    expect(sds.output).to eq({
      resources: {},
      outputs: {}
    })
  end

  it "outputs a simple hash with resources" do
    script = <<~SCRIPT
      SecGroup: 
        Type: AWS::EC2::SecurityGroup
        Properties:
          GroupDescription: Some Security group
          SecurityGroupEgress:
            - CidrIp: 127.0.0.1/32
              IpProtocol: -1
          VpcId: "{{ constant(Barcelona::VPC) }}"
    SCRIPT

    sds = StackDescriberService.new(script, 
    {
      vpc_id: 'vpc-abcdefg'
    })

    expect(sds.output).to eq({
      resources: {
        SecGroup: {
          Type: "AWS::EC2::SecurityGroup",
          Properties: {
            GroupDescription: "Some Security group",
            SecurityGroupEgress: [
              {
                CidrIp: "127.0.0.1/32",
                IpProtocol: "-1"
              }
            ],
            VpcId: 'vpc-abcdefg'
          }
        }
      },
      outputs: {}
    })
  end

  it "extracts raw script correctly" do
    script = <<~SCRIPT
      SecGroup: 
        Type: AWS::EC2::SecurityGroup
        Properties:
          GroupDescription: Some Security group
          SecurityGroupEgress:
            - CidrIp: 127.0.0.1/32
              IpProtocol: -1
          VpcId: "{{ constant(Barcelona::VPC) }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect(sds.raw_script).to eq({
      "SecGroup"=>{
        "Type"=>"AWS::EC2::SecurityGroup", 
        "Properties"=>{
          "GroupDescription"=>"Some Security group",
          "SecurityGroupEgress"=>[
            {"CidrIp"=>"127.0.0.1/32", "IpProtocol"=>-1}
          ],
          "VpcId"=>"{{ constant(Barcelona::VPC) }}"
        }
      }
    })
  end
end
