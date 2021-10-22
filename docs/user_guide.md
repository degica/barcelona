# User Guide
## Endpoint

Endpoint is an HTTP/HTTPS endpoint that receives HTTP/HTTPS requests from the Internet and proxies them to your app.
Endpoint consists of ALB (Application Load Balancer), ACM (Amazon Certificate Manager) certificate, and Route53 record.

### Create a new endpoint

```
$ bcn endpoint create --district=<district name> --certificate-arn=<ACM certificate ARN> --public
```

#### Options

- `--district`: District name where you want to create a new endpoint
- `--certificate-arn` ACM Certificate ARN
  - If you specify this option, Barcelona automatically configures the endpoint so that it accepts HTTPS requests.
  - Note that if you do not specify it, HTTPS will not be available on your endpoint.
- `--public`: If specified, Endpoint accepts requests from the Internet. If not, Endpoint is visible only from district's private network

## Heritage

In Barcelona, Your applications are called "Heritage".

### barcelona.yml

All heritage configurations are declared in a barcelona configuration file `barcelona.yml`

```
environments:
  production:
    name: barcelona
    image_name: public.ecr.aws/degica/barcelona
    services:
      - name: web
        service_type: web
        cpu: 128
        memory: 256
        command: puma -C config/puma.rb
        force_ssl: true
        listeners:
          - endpoint: barcelona
            health_check_path: /health_check
      - name: worker
        command: rake jobs:work
        cpu: 128
        memory: 256
```

### Create

```
$ bcn create -e <environment> --district=<district name> --tag=<tag name>
```

### Deploy new version

```
$ bcn deploy -e <environment> --tag=<tag name>
```

## Service

## Interactive Command

Once you create your heritage, you can run interactive commands in a district environment (where your application is running)

```
$ bcn run -e <environment> --user=<username> --memory=<memory size in MB> command...
```

### Options

- `-e`: App environment
- `--user`: username in an interactive command container. Default: user specified in the docker image
- `--memory`: Memory size in MB that will be assigned to your command container. Default: 512

## Scheduled Tasks

TODO

## Environment Variables

### Set Environment Variables

You can set environment variables to your heritage.

```
$ bcn env set -e <environment> --secret KEY1=VALUE1 KEY2=VALUE2...
```

Environment variables will be applied to all containers that belong to your heritage such as services, `before_deploy` container, scheduled tasks, and interactive command container

#### Options

- `-e`: environment. `-e` and `-H` are exclusive
- `-H`: Heritage name. `-e` and `-H` are exclusive
- `--secret`: If set, variables are considered as secret. You can't see secret variables via `bcn env get`, only running containers have access to secret variables

### Get Environment Variables

```
$ bcn env get -e <environment>
```

#### Options

- `-e`: environment. `-e` and `-H` are exclusive
- `-H`: Heritage name. `-e` and `-H` are exclusive
