FROM degica/rails-base:debian

RUN apt-get update && apt-get install -y openssh-client --no-install-recommends && rm -rf /var/lib/apt/lists/*
ADD . $APP_HOME
RUN rake assets:precompile

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
