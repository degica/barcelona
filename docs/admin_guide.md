# Admin Guide
## Bootstrap

See Getting Started page.

## District

District is a set of fundamental AWS resources that are required to run your applications.
District consists of

- VPC
- Subnets
- Security Groups
- NAT Gateway
- EC2 Instances for ECS
- EC2 Instance for bastion server
- AutoScalingGroup
- ECS cluster
- S3 Bucket
- SNS Topic
- and more

When you bootstrap Barcelona, it automatically creates `default` district. Typically you only need to have `default` district but for some cases (mostly security reasons) you would need to create more districts.

### Network Separation

Resources in a same district share network. In AWS point of view, A district has only one VPC, and all resources in the district will be placed in the VPC. If you have an application that must be very secure and isolated from any other resources (e.g. because of HIPAA or PCI DSS requirements) you need to create multiple districts.

### AWS Account Separation

Sometimes you want to have multiple AWS accounts for various reasons. In Barcelona, each district can be in a different AWS account.

### Create a new district

```
$ bcn district create \
  --region=<AWS region> \
  --nat-type=<NAT type> \
  [District name]
```

#### Options

- `--region`: AWS region
- `--nat-type`: NAT type. The default is `instance`. Available values are as follows
  - `instance`: Create a `t2.nano` EC2 instance for NAT instance. This is the cheapest option and suited for development purpose
  - `managed_gateway`: Create AWS-managed NAT gateway.
  - `managed_gateway_multi_az`: Create AWS-managed NAT gateways in each public subnet

### Update a district

```
$ bcn district update \
  --nat-type=<NAT type> \
  --cluster-instance-type=<EC2 instance type> \
  --cluster-size=<Cluster size> \
  --apply \
  [District name]
```

#### Options

- `--nat-type`: NAT type. The default is `instance`. Available values are as follows
- `cluster-instance-type`: EC2 instance type for container instances. Default: `t2.small`
- `cluster-size`: EC2 instance count of container instance autoscaling group.
- `--apply`: If specified will apply the change immediately. If not specified changes will be applied when `bcn district apply` command is executed
