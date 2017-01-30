module Barcelona::Network
  class PostgresqlBuilder < CloudFormation::Builder
    def build_resources
      add_resource("AWS::RDS::DBInstance", "DBInstance") do |j|
        j.AllocatedStorage options[:allocated_strage]
        j.AllowMajorVersionUpgrade true
        j.AutoMinorVersionUpgrade true
        j.Engine "postgres"
        j.DBInstanceClass options[:db_instance_class]
        j.DBInstanceIdentifier ref("AWS::StackName")
        j.DBName options[:db_name]
        j.MasterUsername options[:db_user]
        j.MasterUserPassword ref("DBPassword")
        j.MultiAZ options[:multi_az]
        j.VPCSecurityGroups [
          ref("DBSecurityGroup")
        ]
        j.DBSubnetGroupName ref("DBSubnetGroup")
        j.StorageType "gp2"
      end

      add_resource("AWS::EC2::SecurityGroup", "DBSecurityGroup") do |j|
        j.GroupDescription "DB Security Group"
        j.VpcId options[:vpc_id]
        j.SecurityGroupIngress [
          {
            "IpProtocol" => "tcp",
            "FromPort" => 5432,
            "ToPort" => 5432,
            "SourceSecurityGroupId" => options[:db_source_security_group_id]
          }
        ]
      end

      add_resource("AWS::RDS::DBSubnetGroup", "DBSubnetGroup") do |j|
        j.DBSubnetGroupDescription "DB subnet group"
        j.SubnetIds options[:db_subnet_ids]
      end
    end
  end

  class RDSStack < CloudFormation::Stack
    attr_accessor :district, :db_user, :db_name, :engine

    def initialize(name, district,
                   engine:,
                   db_name: 'default',
                   db_user: 'default',
                   multi_az: false,
                   encoding: :utf8,
                   allocated_storage: 5,
                   instance_class: "db.t2.micro")
      @engine = engine
      @district = district
      @db_user = db_user
      @db_name = db_name

      options = {
        db_instance_class: instance_class,
        db_parameter_group: encoding,
        multi_az: multi_az,
        vpc_id: district.vpc_id,
        allocated_strage: allocated_storage,
        db_name: @db_name,
        db_user: @db_user,
        db_subnet_ids: district.subnets("Private").map(&:subnet_id),
        db_source_security_group_id: district.instance_security_group
      }
      super("#{district.name}-rds-#{name}", options)
    end

    def build
      super do |builder|
        case engine
        when :postgresql
          builder.add_builder PostgresqlBuilder.new(self, options)
        else
          raise ArgumentError
        end
      end
    end

    def build_parameters(j)
      j.DBPassword do |j|
        j.Description "Master DB Password"
        j.Type "String"
        j.NoEcho true
      end
    end

    def build_outputs(j)
      j.DBEndpoint do |j|
        j.Value get_attr("DBInstance", "Endpoint.Address")
      end
    end
  end
end
