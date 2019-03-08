require "rails_helper"

describe Barcelona::Network::NetworkStack do
  let(:district) { create :district }

  it "generates network stack CF template" do
    district.nat_type = nil
    stack = described_class.new(district)
    generated = JSON.load(stack.target!)
    expect(generated["Description"]).to eq "AWS CloudFormation for Barcelona #{stack.name}"
    expect(generated["AWSTemplateFormatVersion"]).to eq "2010-09-09"
    expected = {
      "VPC" => {
        "Type" => "AWS::EC2::VPC",
        "Properties" =>
        {
          "CidrBlock" => district.cidr_block,
          "EnableDnsSupport" => true,
          "EnableDnsHostnames" => true,
          "Tags" =>
          [{"Key" => "Name", "Value" => {"Ref" => "AWS::StackName"}},
           {"Key" => "barcelona", "Value" => district.name}]}},
      "InternetGateway" => {
        "Type" => "AWS::EC2::InternetGateway",
        "Properties" => {
          "Tags" =>
          [{"Key" => "Name", "Value" => {"Ref" => "AWS::StackName"}},
           {"Key" => "barcelona", "Value" => district.name},
           {"Key" => "Network", "Value" => "Public"}]}},
      "VPCGatewayAttachment" => {
        "Type" => "AWS::EC2::VPCGatewayAttachment",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "InternetGatewayId" => {"Ref" => "InternetGateway"}}},
      "VPCDHCPOptions" => {
        "Type" => "AWS::EC2::DHCPOptions",
        "Properties" => {
          "DomainName" => {
            "Fn::Join" => [" ", ["us-east-1.compute.internal", "bcn"]]},
          "DomainNameServers" => ["AmazonProvidedDNS"]}},
      "VPCDHCPOptionsAssociation" => {
        "Type" => "AWS::EC2::VPCDHCPOptionsAssociation",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "DhcpOptionsId" => {"Ref" => "VPCDHCPOptions"}}},
      "LocalHostedZone" => {
        "Type" => "AWS::Route53::HostedZone",
        "Properties" => {
          "Name" => "bcn",
          "VPCs" => [{"VPCId" => {"Ref" => "VPC"}, "VPCRegion" => {"Ref" => "AWS::Region"}}]}},
      "PublicELBSecurityGroup" => {
        "Type" => "AWS::EC2::SecurityGroup",
        "Properties" => {
          "GroupDescription" => "SG for Public ELB",
          "VpcId" => {"Ref" => "VPC"},
          "SecurityGroupIngress" => [
            {"IpProtocol" => "tcp",
             "FromPort" => 80,
             "ToPort" => 80,
             "CidrIp" => "0.0.0.0/0"},
            {"IpProtocol" => "tcp",
             "FromPort" => 443,
             "ToPort" => 443,
             "CidrIp" => "0.0.0.0/0"},
            {"IpProtocol" => "-1",
             "FromPort" => "-1",
             "ToPort" => "-1",
             "CidrIp" => district.cidr_block}],
          "Tags" => [{"Key" => "barcelona", "Value" => district.name}],
        }
      },
      "PublicELBSecurityGroupEgress" => {
        "Type" => "AWS::EC2::SecurityGroupEgress",
        "Properties" => {
          "GroupId" => {"Ref" => "PublicELBSecurityGroup"},
          "IpProtocol" => "tcp",
          "FromPort" => 1,
          "ToPort" => 65535,
          "SourceSecurityGroupId" => {"Ref" => "InstanceSecurityGroup"}
        }
      },
      "PrivateELBSecurityGroup" => {
        "Type" => "AWS::EC2::SecurityGroup",
        "Properties" => {"GroupDescription" => "SG for Private ELB",
                         "VpcId" => {"Ref" => "VPC"},
                         "SecurityGroupIngress" => [
                           {"IpProtocol" => "tcp",
                            "FromPort" => 1,
                            "ToPort" => 65535,
                            "CidrIp" => district.cidr_block}],
                          "Tags" => [{"Key" => "barcelona", "Value" => district.name}],
                        }
      },
      "PrivateELBSecurityGroupEgress" => {
        "Type" => "AWS::EC2::SecurityGroupEgress",
        "Properties" => {
          "GroupId" => {"Ref" => "PrivateELBSecurityGroup"},
          "IpProtocol" => "tcp",
          "FromPort" => 1,
          "ToPort" => 65535,
          "SourceSecurityGroupId" => {"Ref" => "InstanceSecurityGroup"}
        }
      },
      "ContainerInstanceAccessibleSecurityGroup" => {
        "Type" => "AWS::EC2::SecurityGroup",
        "Properties" => {
          "GroupDescription" => "accessible to container instances",
          "VpcId" => {"Ref" => "VPC"},
          "Tags" => [{"Key" => "barcelona", "Value" => district.name}]
        }
      },
      "ContainerInstanceAutoScalingGroup" => {
        "Type"=>"AWS::AutoScaling::AutoScalingGroup",
        "Properties" => {
          "DesiredCapacity" => 1,
          "Cooldown" => 0,
          "HealthCheckGracePeriod" => 0,
          "MaxSize" => 3,
          "MinSize" => 1,
          "HealthCheckType" => "EC2",
          "LaunchConfigurationName" => {"Ref" => "ContainerInstanceLaunchConfiguration"},
          "VPCZoneIdentifier"=>[
            {"Ref" => "SubnetTrusted1"},
            {"Ref"=>"SubnetTrusted2"}
          ],
          "Tags" => [
            {"Key"=>"Name", "Value"=>"barcelona-container-instance", "PropagateAtLaunch"=>true},
            {"Key"=>"barcelona", "Value"=>district.name, "PropagateAtLaunch"=>true},
            {"Key"=>"barcelona-role", "Value"=>"ci", "PropagateAtLaunch"=>true}
          ]
        },
        "UpdatePolicy" => {
          "AutoScalingRollingUpdate" => {
            "MaxBatchSize" => 1,
            "MinInstancesInService" => 1
          }
        }
      },
      "ContainerInstanceLaunchConfiguration" => {
        "Type" => "AWS::AutoScaling::LaunchConfiguration",
        "Properties" => {
          "IamInstanceProfile" => {"Ref"=>"ECSInstanceProfile"},
          "ImageId" => kind_of(String),
          "InstanceType" => "t3.small",
          "SecurityGroups" => [{"Ref"=>"InstanceSecurityGroup"}],
          "UserData" => instance_of(String),
          "EbsOptimized" => true,
          "BlockDeviceMappings" => [
            {
              "DeviceName"=>"/dev/xvda",
              "Ebs" => {"DeleteOnTermination"=>true, "VolumeSize"=>100, "VolumeType"=>"gp2"}
            }
          ]
        }
      },
      "ASGSNSTopic" => {
        "Type" => "AWS::SNS::Topic",
        "Properties" => {
          "Subscription" => [
            {
              "Endpoint" => {"Fn::GetAtt" => ["ASGDrainingFunction", "Arn"]},
              "Protocol" => "lambda"
            }
          ]
        }
      },
      "ASGDrainingFunctionRole" => {
        "Type"=>"AWS::IAM::Role",
        "Properties" => {
          "AssumeRolePolicyDocument" => {
            "Version" => "2012-10-17",
            "Statement" => [
              {
                "Effect"=>"Allow",
                "Principal" => {
                  "Service" => ["lambda.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          },
          "Path" => "/",
          "Policies" => [
            {
              "PolicyName" => "barcelona-#{district.name}-asg-draining-function-role",
              "PolicyDocument" => {
                "Version"=>"2012-10-17",
                "Statement" => [
                  {
                    "Effect"=>"Allow",
                    "Action"=>[
                      "autoscaling:CompleteLifecycleAction",
                      "ecs:ListContainerInstances",
                      "ecs:DescribeContainerInstances",
                      "ecs:UpdateContainerInstancesState",
                      "ecs:ListTasks",
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:PutLogEvents",
                      "sns:Publish"
                    ],
                    "Resource"=>["*"]
                  }
                ]
              }
            }
          ]
        }
      },
      "ASGDrainingFunction" => {
        "Type" => "AWS::Lambda::Function",
        "Properties" => {
          "Code" => {
            "ZipFile" => kind_of(String)
          },
          "Handler" => "index.lambda_handler",
          "Runtime" => "python2.7",
          "Timeout" => "15",
          "Role" => {"Fn::GetAtt" => ["ASGDrainingFunctionRole", "Arn"]},
          "Environment" => {
            "Variables" => {
              "CLUSTER_NAME" => district.name
            }
          }
        },
      },
      "ASGDrainingFunctionPermission" => {
        "Type" => "AWS::Lambda::Permission",
        "Properties" => {
          "FunctionName" => {"Ref" => "ASGDrainingFunction"},
          "Action" => "lambda:InvokeFunction",
          "Principal" => "sns.amazonaws.com",
          "SourceArn" => {"Ref" => "ASGSNSTopic"}
        }
      },
      "LifecycleHookRole" => {
        "Type"=>"AWS::IAM::Role",
        "Properties" => {
          "AssumeRolePolicyDocument" => {
            "Version" => "2012-10-17",
            "Statement" => [
              {
                "Effect"=>"Allow",
                "Principal" => {
                  "Service" => ["autoscaling.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          },
          "ManagedPolicyArns" => [
            "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
          ]
        }
      },
      "TerminatingLifecycleHook" => {
        "Type" => "AWS::AutoScaling::LifecycleHook",
        "Properties" => {
          "AutoScalingGroupName" => {"Ref" => "ContainerInstanceAutoScalingGroup"},
          "LifecycleTransition" => "autoscaling:EC2_INSTANCE_TERMINATING",
          "NotificationTargetARN" => {"Ref" => "ASGSNSTopic"},
          "RoleARN" => {"Fn::GetAtt" => ["LifecycleHookRole", "Arn"]}
        }
      },
      "InstanceSecurityGroup" => {
        "Type" => "AWS::EC2::SecurityGroup",
        "Properties" => {
          "GroupDescription" => "SG for ECS container instances",
          "VpcId" => {"Ref" => "VPC"},
          "SecurityGroupIngress" => [
            {"IpProtocol" => "tcp",
             "FromPort" => 22,
             "ToPort" => 22,
             "SourceSecurityGroupId" => {"Ref" => "SecurityGroupBastion"}},
            {"IpProtocol" => "icmp",
             "FromPort" => -1,
             "ToPort" => -1,
             "CidrIp" => district.cidr_block},
            {"IpProtocol" => -1,
             "FromPort" => -1,
             "ToPort" => -1,
             "SourceSecurityGroupId" => {"Ref" => "PublicELBSecurityGroup"}},
            {"IpProtocol" => -1,
             "FromPort" => -1,
             "ToPort" => -1,
             "SourceSecurityGroupId" => {"Ref" => "PrivateELBSecurityGroup"}},
            {"IpProtocol" => -1,
             "FromPort" => -1,
             "ToPort" => -1,
             "SourceSecurityGroupId" =>
             {"Ref" => "ContainerInstanceAccessibleSecurityGroup"}}],
          "Tags" => [{"Key" => "barcelona", "Value" => district.name}]
        }
      },
      "InstanceSecurityGroupSelfIngress" => {
        "Type" => "AWS::EC2::SecurityGroupIngress",
        "Properties" => {
          "GroupId" => {"Ref" => "InstanceSecurityGroup"},
          "IpProtocol" => -1,
          "FromPort" => -1,
          "ToPort" => -1,
          "SourceSecurityGroupId" => {"Ref" => "InstanceSecurityGroup"}}},
      "SecurityGroupBastion" => {
        "Type" => "AWS::EC2::SecurityGroup",
        "Properties" => {
          "GroupDescription" => "Security Group for bastion servers",
          "VpcId" => {"Ref" => "VPC"},
          "SecurityGroupIngress" => [
            {"IpProtocol" => "tcp",
             "FromPort" => 22,
             "ToPort" => 22,
             "CidrIp" => "0.0.0.0/0"}],
          "SecurityGroupEgress" => [
            {"IpProtocol" => "tcp",
             "FromPort" => 22,
             "ToPort" => 22,
             "CidrIp" => district.cidr_block},
            {"IpProtocol" => "tcp",
             "FromPort" => 80,
             "ToPort" => 80,
             "CidrIp" => "0.0.0.0/0"},
            {"IpProtocol" => "tcp",
             "FromPort" => 443,
             "ToPort" => 443,
             "CidrIp" => "0.0.0.0/0"},
            {"IpProtocol" => "udp",
             "FromPort" => 1514,
             "ToPort" => 1514,
             "CidrIp" => district.cidr_block},
            {"IpProtocol" => "tcp",
             "FromPort" => 1515,
             "ToPort" => 1515,
             "CidrIp" => district.cidr_block},
          ],
          "Tags" => [{"Key" => "barcelona", "Value" => district.name}]
        }
      },
      "BastionProfile" => {
        "Type" => "AWS::IAM::InstanceProfile",
        "Properties" => {
          "Path" => "/",
          "Roles" => [{"Ref" => "BastionRole"}]
        }
      },
      "BastionRole" => {
        "Type"=>"AWS::IAM::Role",
        "Properties" => {
          "AssumeRolePolicyDocument" => {
            "Version"=>"2012-10-17",
            "Statement" => [
              {
                "Effect"=>"Allow",
                "Principal" => {"Service"=>["ec2.amazonaws.com"]},
                "Action"=>["sts:AssumeRole"]
              }
            ]
          },
          "Path"=>"/",
          "ManagedPolicyArns" => [
            "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
          ],
        }
      },
      "BastionLaunchConfiguration" => {
        "Type" => "AWS::AutoScaling::LaunchConfiguration",
        "Properties" => {
          "InstanceType" => "t3.micro",
          "IamInstanceProfile" => {"Ref" => "BastionProfile"},
          "ImageId" => kind_of(String),
          "UserData" => anything,
          "AssociatePublicIpAddress" => true,
          "SecurityGroups" => [
            {"Ref" => "SecurityGroupBastion"}
          ]
        }
      },
      "BastionAutoScaling" => {
        "Type" => "AWS::AutoScaling::AutoScalingGroup",
        "DependsOn" => ["VPCGatewayAttachment"],
        "Properties" => {
          "DesiredCapacity" => 1,
          "MaxSize" => 1,
          "MinSize" => 1,
          "HealthCheckType" => "EC2",
          "LaunchConfigurationName" => {"Ref" => "BastionLaunchConfiguration"},
          "VPCZoneIdentifier" => [
            {"Ref" => "SubnetDmz1"},
            {"Ref" => "SubnetDmz2"}
          ],
          "Tags" => [
            {
              "Key" => "Name",
              "Value" => "barcelona-#{district.name}-bastion",
              "PropagateAtLaunch" => true
            },
            {
              "Key" => "barcelona",
              "Value" => district.name,
              "PropagateAtLaunch" => true
            },
            {
              "Key" => "barcelona-role",
              "Value" => "bastion",
              "PropagateAtLaunch" => true
            }
          ]
        },
        "UpdatePolicy" => {
          "AutoScalingReplacingUpdate" => {
            "WillReplace" => true
          }
        }
      },
      "ECSInstanceProfile" => {
        "Type"=>"AWS::IAM::InstanceProfile",
        "Properties" => {
          "Path" => "/",
          "Roles" => [{"Ref"=>"ECSInstanceRole"}]
        }
      },
      "ECSInstanceRole" => {
        "Type"=>"AWS::IAM::Role",
        "Properties" => {
          "AssumeRolePolicyDocument" => {
            "Version"=>"2012-10-17",
            "Statement" => [
              {
                "Effect"=>"Allow",
                "Principal" => {"Service"=>["ec2.amazonaws.com"]},
                "Action"=>["sts:AssumeRole"]
              }
            ]
          },
          "Path"=>"/",
          "ManagedPolicyArns" => [
            "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
            "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
          ],
          "Policies" => [
            {
              "PolicyName" => "barcelona-ecs-container-instance-role",
              "PolicyDocument" => {
                "Version" => "2012-10-17",
                "Statement" => [
                  {
                    "Effect"=>"Allow",
                    "Action" => [
                      "s3:Get*",
                      "s3:List*"
                    ],
                    "Resource"=>["*"]
                  }
                ]
              }
            }
          ]
        }
      },
      "ECSServiceRole" => {
        "Type"=>"AWS::IAM::Role",
        "Properties" => {
          "AssumeRolePolicyDocument" => {
            "Version" => "2012-10-17",
            "Statement" => [
              {
                "Effect"=>"Allow",
                "Principal" => {
                  "Service" => ["ecs.amazonaws.com"]
                },
                "Action" => ["sts:AssumeRole"]
              }
            ]
          },
          "Path" => "/",
          "Policies" => [
            {
              "PolicyName" => "barcelona-ecs-service-role",
              "PolicyDocument" => {
                "Version"=>"2012-10-17",
                "Statement" => [
                  {
                    "Effect"=>"Allow",
                    "Action"=>[
                      "elasticloadbalancing:Describe*",
                      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                      "ec2:Describe*",
                      "ec2:AuthorizeSecurityGroupIngress"
                    ],
                    "Resource"=>["*"]
                  }
                ]
              }
            }
          ]
        }
      },
      "RouteTableDmz1" => {
        "Type" => "AWS::EC2::RouteTable",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "public"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Public"}]}},
      "RouteDmz1" => {
        "Type" => "AWS::EC2::Route",
        "DependsOn" => ["VPCGatewayAttachment"],
        "Properties" => {
          "RouteTableId" => {"Ref" => "RouteTableDmz1"},
          "DestinationCidrBlock" => "0.0.0.0/0",
          "GatewayId" => {"Ref" => "InternetGateway"}}},
      "SubnetDmz1" => {
        "Type" => "AWS::EC2::Subnet",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "CidrBlock" => (IPAddr.new(district.cidr_block) | (129 << 8)).to_s + "/24",
          "AvailabilityZone" =>
          {"Fn::Select" => [0, {"Fn::GetAZs" => {"Ref" => "AWS::Region"}}]},
          "Tags" => [
            {"Key" => "Name",
             "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "Dmz1"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Public"}]}},
      "SubnetRouteTableAssociationDmz1" => {
        "Type" => "AWS::EC2::SubnetRouteTableAssociation",
        "Properties" => {
          "SubnetId" => {"Ref" => "SubnetDmz1"},
          "RouteTableId" => {"Ref" => "RouteTableDmz1"}}},
      "RouteTableDmz2" => {
        "Type" => "AWS::EC2::RouteTable",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "public"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Public"}]}},
      "RouteDmz2" => {
        "Type" => "AWS::EC2::Route",
        "DependsOn" => ["VPCGatewayAttachment"],
        "Properties" => {
          "RouteTableId" => {"Ref" => "RouteTableDmz2"},
          "DestinationCidrBlock" => "0.0.0.0/0",
          "GatewayId" => {"Ref" => "InternetGateway"}}},
      "SubnetDmz2" => {
        "Type" => "AWS::EC2::Subnet",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "CidrBlock" => (IPAddr.new(district.cidr_block) | (130 << 8)).to_s + "/24",
          "AvailabilityZone" => {"Fn::Select" => [1, {"Fn::GetAZs" => {"Ref" => "AWS::Region"}}]},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "Dmz2"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Public"}]}},
      "SubnetRouteTableAssociationDmz2" => {
        "Type" => "AWS::EC2::SubnetRouteTableAssociation",
        "Properties" => {
          "SubnetId" => {"Ref" => "SubnetDmz2"},
          "RouteTableId" => {"Ref" => "RouteTableDmz2"}}},
      "RouteTableTrusted1" => {
        "Type" => "AWS::EC2::RouteTable",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "private"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Private"}]}},
      "SubnetTrusted1" => {
        "Type" => "AWS::EC2::Subnet",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "CidrBlock" => (IPAddr.new(district.cidr_block) | (1 << 8)).to_s + "/24",
          "AvailabilityZone" => {"Fn::Select" => [0, {"Fn::GetAZs" => {"Ref" => "AWS::Region"}}]},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "Trusted1"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Private"}]}},
      "SubnetRouteTableAssociationTrusted1" => {
        "Type" => "AWS::EC2::SubnetRouteTableAssociation",
        "Properties" => {
          "SubnetId" => {"Ref" => "SubnetTrusted1"},
          "RouteTableId" => {"Ref" => "RouteTableTrusted1"}}},
      "RouteTableTrusted2" => {
        "Type" => "AWS::EC2::RouteTable",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "private"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Private"}]}},
      "SubnetTrusted2" => {
        "Type" => "AWS::EC2::Subnet",
        "Properties" => {
          "VpcId" => {"Ref" => "VPC"},
          "CidrBlock" => (IPAddr.new(district.cidr_block) | (2 << 8)).to_s + "/24",
          "AvailabilityZone" => {
            "Fn::Select" => [1, {"Fn::GetAZs" => {"Ref" => "AWS::Region"}}]},
          "Tags" => [
            {"Key" => "Name", "Value" => {"Fn::Join" => ["-", [{"Ref" => "AWS::StackName"}, "Trusted2"]]}},
            {"Key" => "barcelona", "Value" => district.name},
            {"Key" => "Network", "Value" => "Private"}]}},
      "SubnetRouteTableAssociationTrusted2" => {
        "Type" => "AWS::EC2::SubnetRouteTableAssociation",
        "Properties" => {
          "SubnetId" => {"Ref" => "SubnetTrusted2"},
          "RouteTableId" => {"Ref" => "RouteTableTrusted2"}}},
      "NotificationTopic" => {
        "Type" => "AWS::SNS::Topic",
        "Properties" => {
          "DisplayName" => "district-#{district.name}-notification"
        }
      },
      "BucketPolicy" => {
        "Type" => "AWS::S3::BucketPolicy",
        "Properties" => {
          "Bucket" => district.s3_bucket_name,
          "PolicyDocument" => {
            "Statement" => [
              {
                "Action" => ["s3:PutObject"],
                "Effect" => "Allow",
                "Resource" => {
                  "Fn::Join" => ["",
                                 ["arn:aws:s3:::",
                                  "#{district.s3_bucket_name}/elb_logs/*/AWSLogs/",
                                  {"Ref" => "AWS::AccountId"},
                                  "/*"
                                 ]
                                ],
                },
                "Principal" => {"AWS" => Barcelona::Network::ELB_ACCOUNT_IDS[district.region]}
              }
            ]
          }
        }
      }
    }
    expect(generated["Resources"]).to match expected
  end

  context "when nat_type is instance" do
    it "includes NAT resources" do
      district.nat_type = "instance"
      stack = described_class.new(district)
      generated = JSON.load(stack.target!)
      expect(generated["Resources"]["NATInstance1"]).to be_present
      expect(generated["Resources"]["SecurityGroupNAT"]).to be_present
      expect(generated["Resources"]["RouteNATForRouteTableTrusted1"]).to be_present
    end
  end

  context "when nat_type is managed_gateway" do
    it "includes NAT resources" do
      district.nat_type = "managed_gateway"
      stack = described_class.new(district)
      generated = JSON.load(stack.target!)
      expect(generated["Resources"]["EIPForNATManagedGateway1"]).to be_present
      expect(generated["Resources"]["EIPForNATManagedGateway1"]["DeletionPolicy"]).to eq "Retain"
      expect(generated["Resources"]["NATManagedGateway1"]).to be_present
      expect(generated["Resources"]["RouteNATForRouteTableTrusted1"]).to be_present
    end
  end

  context "when nat_type is managed_gateway_multi_az" do
    it "includes NAT resources" do
      district.nat_type =  "managed_gateway_multi_az"
      stack = described_class.new(district)
      generated = JSON.load(stack.target!)
      expect(generated["Resources"]["EIPForNATManagedGateway1"]).to be_present
      expect(generated["Resources"]["EIPForNATManagedGateway1"]["DeletionPolicy"]).to eq "Retain"
      expect(generated["Resources"]["NATManagedGateway1"]).to be_present
      expect(generated["Resources"]["RouteNATForRouteTableTrusted1"]).to be_present
      expect(generated["Resources"]["EIPForNATManagedGateway2"]).to be_present
      expect(generated["Resources"]["EIPForNATManagedGateway2"]["DeletionPolicy"]).to eq "Retain"
      expect(generated["Resources"]["NATManagedGateway2"]).to be_present
      expect(generated["Resources"]["RouteNATForRouteTableTrusted2"]).to be_present
    end
  end
end
