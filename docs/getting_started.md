# Getting Started
## Bootstrap

To start using Barcelona, you'll first need to deploy Barcelona API service.
Install docker in your machine and run the bellow command.

```
$ docker run --rm -it quay.io/degica/barcelona bin/bootstrap
```

## Install Barcelona Client

1. Download [Barcelona client](https://github.com/degica/barcelona-cli/releases)
2. Unzip and place the binary on your `PATH`


## Login Barcelona

```
$ bcn login https://<barcelona domain>
```

You will be asked GitHub token. Provide it and `bcn` generates an SSH key pair and register the public key to Barcelona service.

Now you have logged in. Try the below command to get district list.

```
$ bcn district list
```

This command shows a list of districts that your Barcelona has. At this point, Barcelona only has `default` district where Barcelona API service is running.

## Your First App

### Create Endpoint

Run the below command.

```
$ bcn endpoint create --district=default my-endpoint
```

This command creates a new endpoint in the default district.
Endpoint is an HTTP/HTTPS endpoint that receives HTTP/HTTPS requests from the Internet and proxies them to your app.
In the next step, you'll create your app and the app has a relationship with this endpoint.

Run the below command to get the endpoint's domain.

```
$ bcn endpoint show --district=default my-endpoint
```

It will return "DNS Name" once the endpoint creation is done.

### Create your app

Create a new file in the current directory naming it `barcelona.yml` with the following content.

```yaml
environments:
  production:
    name: sinatra-demo
    image_name: k2nr/sinatra-barcelona
    services:
      - name: web
        service_type: web
        cpu: 32
        memory: 128
        command: bundle exec ruby main.rb
        listeners:
          - endpoint: my-endpoint
            health_check_path: /

```

And run the below create command.

```
$ bcn create -e production --district=default
```

It will create your app in the default district.
Wait a few minutes for the app to be created, and access to the endpoint's DNS name.

### Deploy a new version

You can provide a docker image tag for `deploy` command.

```
$ bcn deploy -e production --tag v2
```

Normal work flow is as follows.

1. Develop your application
2. build and push a docker image and add tag to it
3. `bcn deploy -e production --tag <tag name>`
