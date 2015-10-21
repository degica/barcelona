#!/bin/bash

cat /nginx.conf.erb | erb > /etc/nginx/nginx.conf
exec nginx -g "daemon off;" $@
