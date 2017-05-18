module Barcelona
  module Network
    class BastionAutoScaling < CloudFormation::Resource
      def self.type
        "AWS::AutoScaling::AutoScalingGroup"
      end

      def define_resource(j)
        super
        j.Properties do |j|
          j.DesiredCapacity 1
          j.MaxSize 1
          j.MinSize 1
          j.HealthCheckType "EC2"
          j.LaunchConfigurationName ref("BastionLaunchConfiguration")
          j.VPCZoneIdentifier [ref("SubnetDmz1"), ref("SubnetDmz2")]
          j.Tags [
            {
              "Key" => "Name",
              "Value" => "barcelona-#{options[:district_name]}-bastion",
              "PropagateAtLaunch" => true
            },
            {
              "Key" => "barcelona",
              "Value" => options[:district_name],
              "PropagateAtLaunch" => true
            },
            {
              "Key" => "barcelona-role",
              "Value" => "bastion",
              "PropagateAtLaunch" => true
            }
          ]
        end

        j.UpdatePolicy do |j|
          j.AutoScalingReplacingUpdate do |j|
            j.WillReplace true
          end
        end
      end
    end
  end
end
