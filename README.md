# Barcelona

Barcelona is the next generation of our infrastructure.

## Status

Prior to alpha status.

## Philosophy

Barcelona tries to be tied with AWS managed services(ECS, ELB, VPC) so that we have less amount of ops tasks.
Barcelona will not offer new concpets. It's a simple wrapper service on top of AWS EC2 Container Service(ECS). All data or configurations in Barcelona are directly linked to AWS resource.

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

Currently only users in `developers` team of `degica` organinzation can login.

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

## TODO

- Logentries integration
- scheduled tasks(cron integration)
- interactive command execution
- Slack integration
