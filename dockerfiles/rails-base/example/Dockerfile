FROM degica/rails-base:2.4

# You can install additional packages
RUN apt-get update && apt-get install -y openssh-client --no-install-recommends && rm -rf /var/lib/apt/lists/*

ADD . $APP_HOME

# Unroot container
# Firstly, added files should be owned by the running user (app)
RUN chown -R app:app $APP_HOME
# Change running user to app
USER app

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
