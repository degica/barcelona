FROM ruby:2.6.5

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      file \
      git \
      unzip \
      curl \
      autoconf \
      automake \
      default-libmysqlclient-dev \
      default-mysql-client \
      g++ \
      gcc \
      gnupg \
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
      libpq-dev \
      libsqlite3-dev \
      libxml2-dev \
      qt5-default \
      libqt5webkit5-dev \
      gstreamer1.0-plugins-base \
      gstreamer1.0-tools \
      gstreamer1.0-x \
      imagemagick \
 && rm -rf /var/lib/apt/lists/*

# Install Node JS
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
   && apt-get install -y nodejs \
   && rm -rf /var/lib/apt/lists/*
RUN npm install -g yarn

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

