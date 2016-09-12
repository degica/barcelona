# Barcelona runpack container

## Development

Basically this image is intended to run in ECS cluster but you can emulate the ECS behavior as follows

```
$ make build
$ docker run --name runpack quay.io/degica/barcelona-run-pack
$ docker run --volumes-from runpack debian:jessie /barcelona/barcelona-run load-env-and-run \
    --region ap-northeast-1 \
    --bucket-name your-s3-bucket-name \
    -e ENV_NAME=s3/path \
    env
```
