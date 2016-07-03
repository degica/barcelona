FROM degica/rails-base:debian

ADD . $APP_HOME

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
