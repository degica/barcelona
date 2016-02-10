# Barcelona

Barcelona is the next generation of our infrastructure.

## Status

Prior to alpha status.

## Philosophy

Barcelona tries to be tied with AWS managed services(ECS, ELB, VPC) so that we have less amount of ops tasks.
Barcelona will not offer new concepts. It's a simple wrapper service on top of AWS EC2 Container Service(ECS). All data or configurations in Barcelona are directly linked to AWS resource.

### District

`District` is basically same as AWS ECS's cluster. It also has several associations to provide proper AWS configuration:

- `vpc_id`
- `public_elb_security_group`
- `private_elb_security_group`
- `ecs_service_role`
- `ecs_instance_role`
- `instance_security_group`

District manages the above AWS resources and EC2 instances running as an ECS cotainer instance.

### Heritage

`Heritage` represents a micro-service. Assume that you have a heritage called `komoju-core-app`(which is identical to the current hats repository). `komoju-core-app` heritage would have several "services" such as

- web
  - run by rails application and it listens on http/https
- worker
  - delayed_job
- cron

So the `komoju-core-app` heritage has 3 services: `web`, `worker`, `cron`. each service can independently scale out/in for example web with scale 4, worker with scale 2, cron with scale 1.

Once you create a heritage, Barcelona make AWS ECS's `create-service` request and ECS pull and run the specified docker image on the ECS container instances.

Additionally, We also may want another heritage `komoju-core-front` which runs nginx as a reverse-proxy for `komoju-core-app`.

## Usage

### Authentication

Currently only users in the `developers` team of `degica` organization can login.

1. [Create Github access token](https://github.com/settings/tokens) with permission `read:org`
2. login by `curl -XPOST -H "X-GitHub-Token: [your GitHub access token]" http://localhost:3000/login`
  - the response includes barcelona access token: `{"login":"k2nr","token":"24106f22c0b6c0e0a032cb001229c2e9d8009cd7"}`
3. You can call Barcelona API with the token: `curl -H "X-Barcelona-Token: 24106f22c0b6c0e0a032cb001229c2e9d8009cd7" http://localhost:3000/districts`

### API

Barcelona provides a Restful API

- Cluster management
  - POST /districts
  - PATCH /districts/:district_name
  - DELETE /districts/:district_name
- Application management
  - POST /districts/:district_name/heritages
  - DELETE /heritages/:heritage_name
  - Environment variables management
    - POST /heritages/:heritage_name/env_vars
    - DELETE /heritages/:heritage_name/env_vars
  - Scale out/in
    - POST /heritages/:heritage_name/services/:service_name/scale

## IAM users and roles

### IAM user for Barcelona API

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1445588337000",
            "Effect": "Allow",
            "Action": [
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:StartInstances",
                "ec2:DescribeInstances",
                "ec2:DescribeSubnets",
                "ecs:*",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "route53:ChangeResourceRecordSets",
                "route53:GetHostedZone",
                "s3:PutObject",
                "iam:PassRole"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

### ECS instance role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
```

### ECS service role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer"
      ],
      "Resource": "*"
    }
  ]
}
```

## TODO

- Logentries integration
- scheduled tasks(cron integration)
- interactive command execution
- Slack integration
