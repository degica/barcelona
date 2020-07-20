# reverse-proxy

The reverse-proxy Dockerfile is the Barcelona support reverse proxy (based on nginx) that is configured to cleanly integrate with the other Barcelona images.

## Testing

To test the reverse-proxy image in isolation you can use the `docker-compose.test.yml` file:
```bash
$ docker-compose -f docker-compose.test.yml build
$ docker-compose -f docker-compose.test.yml up
```

This will start a simple webserver on port `50132`, which can be used for testing that the nginx config is working as intended. The Nginx logs are being directed to stdout so you should see any logs appearing in the docker-compose session, or if you started it in detached mode you can run `docker-compose -f docker-compose.test.yml logs` to see the nginx log output.