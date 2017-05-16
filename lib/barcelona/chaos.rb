module Barcelona
  class Chaos
    attr_accessor :district, :terminate_count

    def self.run(district_names, count:)
      District.where(name: district_names.uniq).each do |d|
        self.new(d, count).run
      end
    end

    def initialize(district, terminate_count)
      @district = district
      @terminate_count = terminate_count
    end

    def run
      instances = district.container_instances.sort_by { |i| i[:launch_time] }
      non_active_count = instances.select { |i| i[:status] != 'ACTIVE' }.count
      if non_active_count > 0
        notify("#{district.name} has one or more non-active instance(s). Skipping", level: :warn)
        return
      end

      asg = district.aws.autoscaling

      # Terminate n oldest instances
      terminate_count.times do |n|
        ins = instances[n]
        break if ins.nil?
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
