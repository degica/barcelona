FROM ruby:2.6.5-stretch

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
      gettext \
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

RUN wget https://github.com/git/git/archive/v2.26.2.tar.gz -O git.tar.gz \
 && tar xvf git.tar.gz \
 && cd git-2.26.2 && make prefix=/usr/local -j4 install \
 && cd .. && rm git.tar.gz && rm -rf git-2.26.2 \
 git --version

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

