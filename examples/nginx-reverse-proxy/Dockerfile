FROM nginx:1.9.5

RUN apt-get update && \
    apt-get install -q -y ruby && \
    rm -rf /var/lib/apt/lists/*

ENV RESOLVER_IP 169.254.169.253

COPY nginx.conf.erb /nginx.conf.erb
COPY run.sh /run.sh

CMD ["/run.sh"]
