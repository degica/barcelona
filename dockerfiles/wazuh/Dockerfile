FROM centos:7

COPY wazuh.repo /etc/yum.repos.d/wazuh.repo

RUN groupadd -g 1000 ossec
RUN useradd -u 1000 -g 1000 ossec
RUN yum -y update && \
    yum -y install epel-release && \
    yum -y install openssl postfix mailx cyrus-sasl cyrus-sasl-plain && \
    yum clean all
RUN curl --silent --location https://rpm.nodesource.com/setup_6.x | bash - && \
    yum install -y nodejs
RUN yum install -y wazuh-manager-2.0.1 wazuh-api-2.0.1

COPY data_dirs.env /data_dirs.env
COPY init.bash /init.bash
COPY run.sh /tmp/run.sh
#COPY local_decoder.xml /var/ossec/ruleset/decoders/local_decoder.xml
COPY local_rules.xml /var/ossec/ruleset/rules/local_rules.xml
COPY ossec.conf /var/ossec/ossec.conf
COPY filebeat.yml /etc/filebeat/

RUN /init.bash

RUN  curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-5.4.2-x86_64.rpm &&\
  rpm -vi filebeat-5.4.2-x86_64.rpm && \
  rm filebeat-5.4.2-x86_64.rpm



VOLUME ["/var/ossec/data"]

EXPOSE 55000/tcp 1514/udp 1515/tcp 514/udp

# Run supervisord so that the container will stay alive

ENTRYPOINT ["/tmp/run.sh"]