module Barcelona
  class Chaos
    attr_accessor :district, :terminate_count

    def self.run(district_names, count:)
      District.where(name: district_names.uniq).each do |d|
        new(d, count).run
      end
    end

    def initialize(district, terminate_count)
      @district = district
      @terminate_count = terminate_count
    end

    def run
      instances = district.container_instances.sort_by { |i| i[:launch_time] }
      if instances.detect { |i| i[:status] != 'ACTIVE' }
        notify("#{district.name} has one or more non-active instance(s). Skipping", level: :warn)
        return
      end

      asg = district.aws.autoscaling

      # Terminate n oldest instances
      instances[0...terminate_count].each do |ins|
        notify "Terminating #{ins[:ec2_instance_id]}"
        asg.terminate_instance_in_auto_scaling_group(
          instance_id: ins[:ec2_instance_id],
          should_decrement_desired_capacity: false
        )
      end
    end

    def notify(message, level: :good)
      Event.new(district).notify(level: level, message: "[Chaos] #{message}")
    end
  end
end
