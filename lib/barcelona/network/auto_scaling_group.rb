module Barcelona
  module Network
    class AutoScalingGroup < CloudFormation::Resource
      def self.type
        "AWS::AutoScaling::AutoScalingGroup"
      end

      def define_resource(json)
        super
        json.Properties do |j|
          j.DesiredCapacity desired_capacity
          j.Cooldown 0
          j.HealthCheckGracePeriod 0
          j.MaxSize(desired_capacity + 1)
          j.MinSize desired_capacity
          j.HealthCheckType "EC2"
          j.LaunchConfigurationName ref("ContainerInstanceLaunchConfiguration")
          j.VPCZoneIdentifier [ref("SubnetTrusted1"), ref("SubnetTrusted2")]
          j.Tags [
            {
              "Key" => "Name",
              "Value" => "barcelona-container-instance",
              "PropagateAtLaunch" => true
            }
          ]
        end

        json.UpdatePolicy do |j|
          j.AutoScalingRollingUpdate do |j|
            j.MaxBatchSize 1
            j.MinInstancesInService desired_capacity
            j.WaitOnResourceSignals true
            j.PauseTime "PT15M"
          end
        end
      end

      def desired_capacity
        options[:desired_capacity]
      end
    end
  end
end
