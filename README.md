# Barcelona

Barcelona is the next generation of our infrastructure.

## Status

Prior to alpha status.

## Philosophy

Barcelona tries to be tied with AWS managed services(ECS, ELB, VPC) so that we have less amount of ops tasks.
Barcelona will not offer new concpets. It's a simple wrapper service on top of AWS EC2 Container Service(ECS). All data or configurations in Barcelona are directly linked to AWS resource.

## Architecture

Barcelona consists of

- Front Restful API which eventually make requests to AWS API
- AWS resources as a backend
  - ECS(AWS container service) for docker container management
  - ELB + Route53 for service discovery and load balancing

All of your applications will run on ECS container instances and registered to an ELB dedicated for an application. The ELB endpoint URL is resolved by Route53 CNAME record(for private services) or A ALIAS record(for public-facing services)

Barcelona has 2 important resources: `District` and `Heritage`

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

## TODO

- Auth
- Logentries integration
- scheduled tasks(cron integration)
- interactive command execution
- Slack integration
