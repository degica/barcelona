# Barcelona

Barcelona is a PaaS built on top of AWS. Barcelona manages AWS cluster (VPC, EC2, AutoScaling, ECS, ELB/ALB, etc.), application deployments with docker and ECS, and provides utility functions to manage your applications.

# Documentation

https://github.com/degica/barcelona/tree/master/docs

# Development

## Prerequisites

To start development, you need to install docker and docker-compose.

- For Mac, use [Docker for Mac](https://docs.docker.com/engine/installation/mac/#/docker-for-mac)
- For Linux, install `docker` and `docker-compose` on your machine.

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

Now your Barcelona server is running at `localhost:3333`. Try logging in with the below command.

```
$ bcn login http://localhost:3333 
```

# LICENSE

MIT
