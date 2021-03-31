require "rails_helper"

describe StackDescriberService do
  it "outputs a simple hash" do
    sds = StackDescriberService.new('{}', {})
    expect(sds.output).to eq({
      resources: {},
      outputs: {}
    })
  end

  it "prohibits the use of global modules" do
    # security
    script = <<~SCRIPT
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ ::Object.new }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect { sds.output }.to raise_error InvalidConstantException
  end

  it "prohibits the use of global modules hack 1" do
    # security
    script = <<~SCRIPT
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ a = (::Object.new) }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect { sds.output }.to raise_error InvalidConstantException
  end

  it "prohibits the use of global modules hack 2" do
    # security
    script = <<~SCRIPT
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ a = [Class.new] }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect { sds.output }.to raise_error InvalidConstantException
  end

  it "prohibits the use of global modules hack 3" do
    # security
    District
    script = <<~SCRIPT
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ a = [District.new] }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect { sds.output }.to raise_error InvalidConstantException
  end

  it "does not get to use extant models" do
    # security
    script = <<~SCRIPT
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ District.meow }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect { sds.output }.to raise_error InvalidConstantException
  end

  it "throws error if input specified but not set" do
    # security
    script = <<~SCRIPT
      Name:
        type: Barcelona::Input::String
      Something:
        type: AWS::Foo::Something
        name: "{{ Name }}"
    SCRIPT

    sds = StackDescriberService.new(script, {
      inputs: {
      }
    })

    expect { sds.output }.to raise_error "Name not set"
  end

  it "throws error if input set but not specified" do
    # security
    script = <<~SCRIPT
      Name:
        type: Barcelona::Input::String
      Something:
        type: AWS::Foo::Something
        name: "{{ Name }}"
    SCRIPT

    sds = StackDescriberService.new(script, {
      inputs: {
        "Name" => "foobar",
        "Age" => 10
      }
    })

    expect { sds.output }.to raise_error "Age not a parameter"
  end

  it "skips inputs for resources" do
    # security
    script = <<~SCRIPT
      Name:
        type: Barcelona::Input::String
      Something:
        type: AWS::Foo::Something
        name: "{{ Name }}"
    SCRIPT

    sds = StackDescriberService.new(script, {
      inputs: {
        "Name" => "hello"
      }
    })

    expect(sds.output).to eq({
      resources: {
        Something: {
          Type: "AWS::Foo::Something",
          Properties: {
            Name: "hello"
          }
        }
      },
      outputs: {}
    })
  end

  it "does get_attr properly" do
    script = <<~SCRIPT
      Something:
        type: AWS::Foo::Something
        name: bar
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ Something.Address }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect(sds.output).to eq({
      resources: {
        Something: {
          Type: "AWS::Foo::Something",
          Properties: {
            Name: "bar"
          }
        },
        SomethingElse: {
          Type: "AWS::Foo::Something",
          Properties: {
            Client: {
              "Fn::GetAtt" => [ "Something", "Address" ]
            }
          }
        }
      },
      outputs: {}
    })
  end

  it "does ref properly" do
    script = <<~SCRIPT
      Something:
        type: AWS::Foo::Something
        name: fobar
      SomethingElse:
        type: AWS::Foo::Something
        client: "{{ Something }}"
    SCRIPT

    sds = StackDescriberService.new(script, {})

    expect(sds.output).to eq({
      resources: {
        Something: {
          Type: "AWS::Foo::Something",
          Properties: {
            Name: "fobar"
          }
        },
        SomethingElse: {
          Type: "AWS::Foo::Something",
          Properties: {
            Client: {
              "Ref" => "Something"
            }
          }
        }
      },
      outputs: {}
    })
  end

  it "throws if ref does not exist" do

  end

  it "outputs a hash with resources" do
    script = <<~SCRIPT
      SecGroup: 
        type: AWS::EC2::SecurityGroup
        group_description: Some Security group
        security_group_egress:
          - CidrIp: 127.0.0.1/32
            IpProtocol: -1
        vpc_id: "{{ Barcelona::VpcId }}"
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

end
