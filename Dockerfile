FROM degica/rails-base:2.5

RUN apt-get update && apt-get install -y openssh-client --no-install-recommends && rm -rf /var/lib/apt/lists/*

ADD . $APP_HOME
RUN chown -R app:app $APP_HOME
USER app
RUN rake assets:precompile

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
