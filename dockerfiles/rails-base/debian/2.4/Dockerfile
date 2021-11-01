FROM ruby:2.4.5-slim-jessie

RUN apt-get clean && apt-get update \
   && apt-get install -y --no-install-recommends \
      file \
      git \
      curl \
   && rm -rf /var/lib/apt/lists/*

RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - \
   && apt-get install nodejs \
   && rm -rf /var/lib/apt/lists/*

ENV PATH=/app/bin:$PATH

ONBUILD ARG UID=1000
ONBUILD ARG APP_HOME=/app
ONBUILD ARG BUNDLE_OPTIONS='--without development test'
ONBUILD ARG SKIP_BUNDLE

ONBUILD RUN useradd --user-group --uid $UID --create-home app
ONBUILD RUN mkdir -p $APP_HOME && chown -R app:app $APP_HOME
ONBUILD WORKDIR $APP_HOME
ONBUILD COPY Gemfile $APP_HOME/
ONBUILD COPY Gemfile.lock $APP_HOME/
ONBUILD ADD vendor $APP_HOME/vendor

ONBUILD RUN apt-get clean && apt-get update && \
            runDeps=' \
              libmysqlclient18 \
              libpq5 \
              libsqlite3-0 \
              libxslt1.1 \
              libxml2 \
              libcurl3 \
            ' && \
            buildDeps=' \
              autoconf \
              automake \
              g++ \
              gcc \
              patch \
              make \
              libbz2-dev \
              libc6-dev \
              liblzma-dev \
              libmagickcore-dev \
              libmagickwand-dev \
              libreadline-dev \
              libtool \
              libxslt-dev \
              libmysqlclient-dev \
              libpq-dev \
              libsqlite3-dev \
              libxml2-dev \
              libcurl3 \
            ' && \
            apt-get install -y --no-install-recommends $buildDeps && \
            ( test "$SKIP_BUNDLE" = "yes" || \
              ( bundle install -j 8 $BUNDLE_OPTIONS && \
                apt-get purge -y --auto-remove $buildDeps && \
                apt-get install -y --no-install-recommends $runDeps && \
                rm -rf /var/lib/apt/lists/* ))
