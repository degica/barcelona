FROM phusion/baseimage:0.9.19
MAINTAINER Kazunori Kajihiro <kkajihiro@degica.com>

RUN apt-get update && apt-get install -y python-software-properties python-requests debconf-utils daemontools wget openjdk-8-jre

RUN wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - &&\
     echo "deb https://packages.elasticsearch.org/logstash/2.1/debian stable main" | tee -a /etc/apt/sources.list

RUN apt-get update && apt-get install -y logstash

ADD preloaded-vars.conf /tmp/

# Install Wazuh OSSEC from source repository
RUN apt-get install -y expect gcc make libssl-dev unzip &&\
    cd root && mkdir ossec_tmp && cd ossec_tmp &&\
    wget https://github.com/wazuh/ossec-wazuh/archive/v1.1.1.tar.gz &&\
    tar xvfz v1.1.1.tar.gz &&\
    mv wazuh-1.1.1 /root/ossec_tmp/ossec-wazuh &&\
    rm v1.1.1.tar.gz &&\
    mv /tmp/preloaded-vars.conf /root/ossec_tmp/ossec-wazuh/etc/preloaded-vars.conf &&\
    /root/ossec_tmp/ossec-wazuh/install.sh &&\
    apt-get remove --purge -y gcc make expect && apt-get clean

ADD default_agent /var/ossec/default_agent
RUN service ossec restart &&\
  /var/ossec/bin/manage_agents -f /default_agent &&\
  rm /var/ossec/default_agent &&\
  service ossec stop &&\
  echo -n "" /var/ossec/logs/ossec.log

##LOGSTASH configuration

ADD logstash.conf /etc/logstash/conf.d/logstash-ossec.conf
RUN cp /root/ossec_tmp/ossec-wazuh/extensions/elasticsearch/elastic-ossec-template.json /etc/logstash/ &&\
    curl -O "http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz" &&\
    gzip -d GeoLiteCity.dat.gz && mv GeoLiteCity.dat /etc/logstash/ &&\
    usermod -a -G ossec logstash

ADD data_dirs.env /data_dirs.env
ADD init.bash /init.bash
ADD run.sh /tmp/
ADD wazuh_kibana_installer.py /tmp/

# Sync calls are due to https://github.com/docker/docker/issues/9547
RUN chmod 755 /init.bash &&\
  sync && /init.bash &&\
  sync && rm /init.bash

VOLUME ["/var/ossec/data"]

EXPOSE 1514/udp 1515/tcp

# Run supervisord so that the container will stay alive

ENTRYPOINT ["/tmp/run.sh"]
