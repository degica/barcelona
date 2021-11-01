FROM ruby:2.4-alpine

RUN apk add --no-cache --virtual .rundeps \
    git \
    ca-certificates \
    mariadb-client-libs \
    libpq \
    sqlite-libs \
    tzdata \
    libxml2 \
    libxslt \
    openssl \
    zlib \
    yaml \
    libcurl \
    nodejs

ONBUILD ARG UID=1000
ONBUILD ARG APP_HOME=/app
ONBUILD ARG BUNDLE_OPTIONS='--without development test'
ONBUILD ARG SKIP_BUNDLE

ONBUILD RUN adduser -D -u $UID app
ONBUILD RUN mkdir -p $APP_HOME && chown -R app:app $APP_HOME
ONBUILD WORKDIR $APP_HOME
ONBUILD COPY Gemfile $APP_HOME/
ONBUILD COPY Gemfile.lock $APP_HOME/
ONBUILD ADD vendor $APP_HOME/vendor

ONBUILD RUN apk add --no-cache --virtual .rundeps
ONBUILD RUN apk add --no-cache --virtual .builddeps \
              autoconf \
              bzip2-dev \
              ca-certificates \
              coreutils \
              g++ \
              gcc \
              gdbm-dev \
              glib-dev \
              libc-dev \
              libffi-dev \
              linux-headers \
              mysql-dev \
              postgresql-dev \
              sqlite-dev \
              libxml2-dev \
              libxslt-dev \
              openssl-dev \
              zlib-dev \
              yaml-dev \
              curl-dev \
              make \
              ncurses-dev \
              procps \
              readline-dev \
              zlib-dev \
         && ( test "$SKIP_BUNDLE" = "yes" \
            || ( bundle install $BUNDLE_OPTIONS && apk del .builddeps ))
