# Rails buildpack

rails-buildpack image includes common dependencies required for a rails application.
You can use `rails-buildpack` for your CI or builder of a multi-stage build.

## multi-stage example

```
FROM degica/rails-buildpack:2.6 AS builder

COPY Gemfile $APP_HOME/
COPY Gemfile.lock $APP_HOME/
RUN bundle install --without development test

ADD package.json $APP_HOME/
ADD yarn.lock $APP_HOME/
RUN yarn

ADD . $APP_HOME

RUN bundle exec rake assets:precompile RAILS_ENV=production


FROM ruby:2.6-slim

ENV APP_HOME=/app

RUN useradd --user-group app
RUN mkdir -p $APP_HOME && chown -R app:app $APP_HOME
WORKDIR $APP_HOME

COPY --from=builder /usr/local/bundle /usr/local/bundle
ADD --chown=app:app . $APP_HOME
COPY --from=builder --chown=app:app public/assets public/assets

USER app
```
