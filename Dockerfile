FROM degica/rails-base:debian

ADD . $APP_HOME
RUN rake assets:precompile

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
