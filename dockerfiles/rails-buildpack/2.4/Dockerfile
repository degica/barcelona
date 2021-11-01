FROM ruby:2.4.5-jessie

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      file \
      git \
      unzip \
      curl \
      autoconf \
      automake \
      libmysqlclient-dev \
      mysql-client \
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
      libcurl3 \
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

# Chrome Driver
ENV CHROMEDRIVER_VERSION 2.45
RUN mkdir -p /opt/chromedriver-$CHROMEDRIVER_VERSION && \
    curl -sS -o /tmp/chromedriver_linux64.zip http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip && \
    unzip -qq /tmp/chromedriver_linux64.zip -d /opt/chromedriver-$CHROMEDRIVER_VERSION && \
    rm /tmp/chromedriver_linux64.zip && \
    chmod +x /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver && \
    ln -fs /opt/chromedriver-$CHROMEDRIVER_VERSION/chromedriver /usr/local/bin/chromedriver

# Google Chrome
RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get -y install google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
