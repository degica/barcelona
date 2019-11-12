# OssecClient plugin
# This plugin adds a wazuh agent which connects to existing ossec manager
# Usage: bcn district put-plugin discrict1 ossec_client -a server_hostname=ossec-manager.local 
# To connect a ossec manager in other VPC, you need to ...
# - Add VPC to Route53 Hosted Zone
# - Create a peering connection
# - Add an entry for peering to both Container VPC and ossec manager VPC
# - Allow access from Container VPC to ossec manager VPC


module Barcelona
  module Plugins
   
    class OssecClientPlugin < Base

      def on_container_instance_user_data(_instance, user_data)
        user_data.run_commands += run_commands
        user_data.packages += ['wazuh-agent']
        user_data.add_file("/etc/yum.repos.d/wazuh.repo", "root:root", "644", <<EOS)
[wazuh_repo]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh
baseurl=https://packages.wazuh.com/yum/el/7/x86_64
protect=1
EOS
        user_data.add_file("/var/ossec/etc/ossec.conf", "root:root", "644", ossec_conf(attributes["server_hostname"]))

        user_data
      end

      def run_commands
        @run_commands ||= [
          "/var/ossec/bin/agent-auth -m #{attributes['server_hostname']}",
          "/var/ossec/bin/ossec-control restart",
        ].flatten
      end

      def ossec_conf(server_hostname)
        <<EOS

    <!--
      Wazuh - Agent - Default configuration for centos 7
      More info at: https://documentation.wazuh.com
      Mailing list: https://groups.google.com/forum/#!forum/wazuh
    -->
    
    <ossec_config>
      <client>
        <server-hostname>#{server_hostname}</server-hostname>
        <config-profile>centos, centos7</config-profile>
        <protocol>udp</protocol>
      </client>
    
      <client_buffer>
        <!-- Agent buffer options -->
        <disable>no</disable>
        <length>5000</length>
        <events_per_second>500</events_per_second>
      </client_buffer>
    
      <!-- Policy monitoring -->
      <rootcheck>
        <disabled>no</disabled>
        <check_unixaudit>yes</check_unixaudit>
        <check_files>yes</check_files>
        <check_trojans>yes</check_trojans>
        <check_dev>yes</check_dev>
        <check_sys>yes</check_sys>
        <check_pids>yes</check_pids>
        <check_ports>yes</check_ports>
        <check_if>yes</check_if>
    
        <!-- Frequency that rootcheck is executed - every 12 hours -->
        <frequency>43200</frequency>
    
        <rootkit_files>/var/ossec/etc/shared/rootkit_files.txt</rootkit_files>
        <rootkit_trojans>/var/ossec/etc/shared/rootkit_trojans.txt</rootkit_trojans>
    
        <system_audit>/var/ossec/etc/shared/system_audit_rcl.txt</system_audit>
        <system_audit>/var/ossec/etc/shared/system_audit_ssh.txt</system_audit>
        <system_audit>/var/ossec/etc/shared/cis_rhel7_linux_rcl.txt</system_audit>
    
        <skip_nfs>yes</skip_nfs>
        <ignore>/var/lib/docker/overlay2</ignore>
      </rootcheck>
      <wodle name="open-scap">
        <disabled>yes</disabled>
        <timeout>1800</timeout>
        <interval>1d</interval>
        <scan-on-start>yes</scan-on-start>
    
        <content type="xccdf" path="ssg-centos-7-ds.xml">
          <profile>xccdf_org.ssgproject.content_profile_pci-dss</profile>
          <profile>xccdf_org.ssgproject.content_profile_common</profile>
        </content>
      </wodle>
    
      <!-- File integrity monitoring -->
      <syscheck>
        <disabled>no</disabled>
    
        <!-- Frequency that syscheck is executed default every 12 hours -->
        <frequency>43200</frequency>
    
        <scan_on_start>yes</scan_on_start>
    
        <!-- Directories to check  (perform all possible verifications) -->
        <directories check_all="yes">/etc,/usr/bin,/usr/sbin</directories>
        <directories check_all="yes">/bin,/sbin,/boot</directories>
    
        <!-- Files/directories to ignore -->
        <ignore>/etc/mtab</ignore>
        <ignore>/etc/hosts.deny</ignore>
        <ignore>/etc/mail/statistics</ignore>
        <ignore>/etc/random-seed</ignore>
        <ignore>/etc/random.seed</ignore>
        <ignore>/etc/adjtime</ignore>
        <ignore>/etc/httpd/logs</ignore>
        <ignore>/etc/utmpx</ignore>
        <ignore>/etc/wtmpx</ignore>
        <ignore>/etc/cups/certs</ignore>
        <ignore>/etc/dumpdates</ignore>
        <ignore>/etc/svc/volatile</ignore>
    
        <!-- Check the file, but never compute the diff -->
        <nodiff>/etc/ssl/private.key</nodiff>
    
        <skip_nfs>yes</skip_nfs>
      </syscheck>
      <!-- Log analysis -->
      <localfile>
        <log_format>command</log_format>
        <command>df -P</command>
        <frequency>360</frequency>
      </localfile>
    
      <localfile>
        <log_format>full_command</log_format>
        <command>netstat -tulpen | sort</command>
        <alias>netstat listening ports</alias>
        <frequency>360</frequency>
      </localfile>
    
      <localfile>
        <log_format>full_command</log_format>
        <command>last -n 20</command>
        <frequency>360</frequency>
      </localfile>
    
      <!-- Active response -->
      <active-response>
        <disabled>no</disabled>
      </active-response>
    
      <!-- Choose between plain or json format (or both) for internal logs -->
      <logging>
        <log_format>plain</log_format>
      </logging>
    
    </ossec_config>
    <ossec_config>
      <localfile>
        <log_format>audit</log_format>
        <location>/var/log/audit/audit.log</location>
      </localfile>
    
      <localfile>
        <log_format>syslog</log_format>
        <location>/var/ossec/logs/active-responses.log</location>
      </localfile>
    
      <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/messages</location>
      </localfile>
    
      <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/secure</location>
      </localfile>
    
      <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/maillog</location>
      </localfile>
    
    </ossec_config>
EOS
      end
    end
  end
end
