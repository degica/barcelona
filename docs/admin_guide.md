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
  - `instance`: Create a `t2.nano` EC2 instance for NAT instance. This is the cheapest option and suited for development purpose
  - `managed_gateway`: Create AWS-managed NAT gateway.
  - `managed_gateway_multi_az`: Create AWS-managed NAT gateways in each public subnet
- `cluster-instance-type`: EC2 instance type for container instances. Default: `t2.small`
- `cluster-size`: EC2 instance count of container instance autoscaling group.
- `--apply`: If specified will apply the change immediately. If not specified changes will be applied when `bcn district apply` command is executed

### Private docker registries

You can set docker credentials with `bcn district put-dockercfg` command.

```
$ bcn district put-dockercfg <district name> -f <dockercfg file path>
```

See [the official document](https://github.com/docker/docker/blob/bbf644ed62cf815cf40ef3de3345fac7ed42588a/docs/sources/use/workingwithrepository.rst#authentication-file) for reference

### Filter Outbound Ports

By default, Barcelona allows all outbound ports to anywhere.
For security reasons, you may want to change this Security Group setting.
Although Barcelona doesn't provide options to change the outbound ports, you can manually update Security Group's "Outbound" setting with AWS web cosole or API.
When you change Barcelona ECS container instance security group, be aware that some outbound ports are required to make Barcelona work:

- `udp:123`, `0.0.0.0/0`
- `tcp:80`, `169.254.169.254/32`
- `tcp:443`, `0.0.0.0/0`

## Plugins

Barcelona provides several plugins which adds/extends Barcelona features.

### PCIDSS plugin

PCIDSS plugin adds security features required by PCI DSS. The features include

- Designated NTP server
- ClamAV virus scan
- OSSEC
  - Barcelona uses [Wazuh](https://github.com/wazuh/wazuh) instead of plain OSSEC
  
This plugin doesn't have attributes, so you just run `bcn district put-plugin --apply <district name> pcidss`

#### Wazuh Kibana proxy

Wazuh has a Kibana integration which enables you to see various information on your browser. Since you need to secure access to Kibana, access to Kibana is limited to private network. To access Wazuh Kibana from your browser, you will need to create a nginx proxy which has basic authentication enabled and setup HTTPS configuration.


Barcelona provides a simple nginx proxy for Wazuh Kibana. If you want just basic auth and HTTPS, you can use the proxy with the following setup.

- Create `barcelona.yml`
  - See `dockerfiles/wazuh-kibana-proxy/barcelona.yml`
- `bcn endpoint create --district=<district name> --public --certificate-arn=<ACM CERT ARN> wazuh-kibana-proxy`
- `bcn create -e production --district=<district name>`
- `bcn env set -e production BAUTH_USER=<username> BAUTH_PASSWORD=password KIBANA_URL=ossec-manager.<district name>.bcn`
- Set domain name for the endpoint
