FROM nginx:alpine

RUN apk add --no-cache curl apache2-utils
RUN mkdir /app
WORKDIR /app
RUN curl -L -o entrykit.tgz https://github.com/progrium/entrykit/releases/download/v0.4.0/entrykit_0.4.0_Linux_x86_64.tgz && \
    tar xzf entrykit.tgz && \
    mv ./entrykit /bin/ && \
    rm ./entrykit.tgz

RUN entrykit --symlink
COPY nginx.conf.tmpl /app/nginx.conf.tmpl
COPY entrypoint /bin/entrypoint

EXPOSE 80
ENV KIBANA_URL=ossec-manager.default.bcn
ENV KIBANA_PORT=5601
ENV BAUTH_USER user
ENV BAUTH_PASSWORD password

CMD ["entrypoint"]