FROM degica/rails-buildpack:2.6

ARG UID=1000
ARG APP_HOME=/app

WORKDIR $APP_HOME

RUN useradd --uid $UID --user-group --create-home app
RUN mkdir -p $APP_HOME && chown -R app:app $APP_HOME
RUN apt-get install -y openssh-client --no-install-recommends

USER app
