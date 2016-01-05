FROM ruby:2.3.0

RUN apt-get update && apt-get install -y postgresql-client nodejs --no-install-recommends && rm -rf /var/lib/apt/lists/*

ENV APP_HOME /app

RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile $APP_HOME/
ADD Gemfile.lock $APP_HOME/
RUN bundle install -j 4

ADD . $APP_HOME
RUN rake assets:precompile

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
