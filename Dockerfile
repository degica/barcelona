FROM degica/rails-buildpack:2.6 AS builder

ENV APP_HOME=/app
WORKDIR $APP_HOME

COPY Gemfile $APP_HOME/
COPY Gemfile.lock $APP_HOME/

RUN bundle install -j=4 --without development test

FROM ruby:2.6.1-slim

ENV APP_HOME=/app
ENV PATH=$APP_HOME/bin:$PATH
WORKDIR $APP_HOME

RUN useradd --user-group --create-home app

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      file \
      git \
      curl \
      libpq5 \
      libsqlite3-0 \
      libxslt1.1 \
      libxml2 \
      libcurl3 \
      openssh-client \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bundle /usr/local/bundle
ADD --chown=app:app . $APP_HOME

USER app

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
