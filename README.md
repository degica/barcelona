# Barcelona

Barcelona is the next generation of our infrastructure.

# Setup Guide
## Install Barcelona Client

1. Setup NPM
2. `npm install -g barcelona`

## Deploy Barcelona

TODO

## Login to Barcelona
### Create GitHub access token

1. Go to https://github.com/settings/tokens
1. create a new token with `read:org` permission

### Run login command

```
$ bcn login http://localhost:3333 [Your GitHub token]
```

# Create a District

District is a set of fundamental AWS resources required to run your applications.
The AWS resoureces include VPC, Subnet, NAT Gateway, AutoScaling Group, S3 bucket, Route53 Hosted zone, bastion servers, etc.

To create a district, run this command. 

```
$ bcn request post /districts '{"name": "your-district", "aws_access_key_id": "<AWS_ACCESS_KEY_ID>", "aws_secret_access_key": "<AWS_SECRET_ACCESS_KEY>", "region": "ap-northeast-1"}'
```

Then Barcelona sets up a district in a specified AWS region using the given access key.
The access key must have "Administrator" permission.
(TODO: the permission can be shrink. I need to list up required actions for district management)

## Create a Heritage

Heritage is an application that runs on a district. It consists of Some ECS resources and ELB.

### Create `barcelona.yml`

Create a file and name it `barcelona.yml`. Our rails application example is [here](https://github.com/degica/barcelona/blob/master/examples/rails-app/barcelona.yml)

Run the below command

```
$ bcn create -e production --district <your district name>
```

# Development

## Prerequisites

To start development you need to install docker.

For mac, use [Docker for Mac](https://docs.docker.com/engine/installation/mac/#/docker-for-mac)
For linux users, install `docker` and `docker-compose` in your machine.

## Running Barcelona Server

Clone this repository

```
$ git clone https://github.com/degica/barcelona
```

Run the server

```
$ make setup
$ make up
```

Now your Barcelona server is running. Try logging in.

```
$ bcn login http://localhost:3333 <YOUR GITHUB TOKEN>
```
