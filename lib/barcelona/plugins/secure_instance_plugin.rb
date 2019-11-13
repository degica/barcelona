# SecureInstance plugin
# This plugin configure container instance and bastion instance more secure
# Usage: bcn district put-plugin discrict1 secure_instance

module Barcelona
  module Plugins
   
    class SecureInstancePlugin < Base

      def on_container_instance_user_data(_instance, user_data)
        user_data.extend SecureUserData
        user_data
      end

      def on_network_stack_template(_stack, template)
        bastion_lc = template["BastionLaunchConfiguration"]
        return template if bastion_lc.nil?

        user_data = InstanceUserData.load_or_initialize(bastion_lc["Properties"]["UserData"])
        user_data.extend SecureUserData
        bastion_lc["Properties"]["UserData"] = user_data.build
        template
      end

      module SecureUserData
        def self.extended(obj)
          obj.configure_security
        end

        def configure_security
          apply_security_update_on_the_first_boot
          install_tools_for_pcidss
          configure_auditd
        end

        def apply_security_update_on_the_first_boot
          self.boot_commands += <<~EOS.split("\n")
            if [ -f /root/.security_update_applied ]
            then
              echo 'security update was already applied, continue initializing...'
            else
              echo 'first boot, applying security update'
              yum update -y --security
              touch /root/.security_update_applied
              echo 'security update was applied, cotinue initialize after reboot...'
              reboot
            fi
          EOS
        end

        def install_tools_for_pcidss
          # Exclude different file systems such as /proc and /dev (-xdev)
          # Files that have changed within a day (-mtime -1)
          scan_command = "listfile=`mktemp` && find / -xdev -mtime -1 -type f -fprint $listfile && clamscan -i -f $listfile | logger -t clamscan"

          self.run_commands += [
            "amazon-linux-extras install -y epel",
            "yum install -y clamav clamav-update tmpwatch fail2ban",

            # Enable freshclam configuration
            "sed -i 's/^Example$//g' /etc/freshclam.conf",
            "sed -i 's/^FRESHCLAM_DELAY=disabled-warn.*$//g' /etc/sysconfig/freshclam",

            # Daily full file system scan
            "echo '0 0 * * * root #{scan_command}' > /etc/cron.d/clamscan",
            "service crond restart",

            # fail2ban configurations
            "echo '[DEFAULT]' > /etc/fail2ban/jail.local",
            "echo 'bantime = 1800' >> /etc/fail2ban/jail.local",
            "service fail2ban restart",

            # SSH session timeout
            "echo 'TMOUT=900 && readonly TMOUT && export TMOUT' > /etc/profile.d/tmout.sh",
          ]
        end

        def configure_auditd
          add_file('/etc/audit/rules.d/audit.rules', "root:root", "600", <<~EOS)
            ## First rule - delete all
            -D
            
            ## Increase the buffers to survive stress events.
            ## Make this bigger for busy systems
            -b 8192
            
            ## Set failure mode to syslog
            -f 1
            
            # rule 4.1.9 Ensure session initiation information is collecte
            -w /var/run/utmp -p wa -k session
            -w /var/log/wtmp -p wa -k logins
            -w /var/log/btmp -p wa -k logins
            
            # rule 4.1.16 Ensure system administrator actions sudolog are collected
            -w /var/log/sudo.log -p wa -k actions
            
            # rule 4.1.6 Ensure events that modify the systems network environment are collected
            -a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
            -a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
            -w /etc/issue -p wa -k system-locale
            -w /etc/issue.net -p wa -k system-locale
            -w /etc/hosts -p wa -k system-locale
            -w /etc/sysconfig/network -p wa -k system-locale
            -w /etc/sysconfig/network-scripts/ -p wa -k system-locale
            
            # rule 4.1.8 Ensure login and logout events are collected
            -w /var/log/lastlog -p wa -k logins
            -w /var/run/faillock/ -p wa -k logins
            
            # rule 4.1.10 Ensure discretionary access control permission modification events are collected, 
            -a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
            -a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
            -a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
            -a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
            -a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
            -a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
            
            # rule 4.1.4 Ensure events that modify date and time information are collected
            -a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
            -a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
            -a always,exit -F arch=b64 -S clock_settime -k time-change
            -a always,exit -F arch=b32 -S clock_settime -k time-change
            -w /etc/localtime -p wa -k time-change
            
            #  rule 4.1.15 Ensure changes to system administration scope sudoers is collected
            -w /etc/sudoers -p wa -k scope
            -w /etc/sudoers.d/ -p wa -k scope
            
            # rule 4.1.14 Ensure file deletion events by users are collected
            -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
            -a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
            
            # rule 4.1.5 Ensure events that modify usergroup information are collected
            -w /etc/group -p wa -k identity
            -w /etc/passwd -p wa -k identity
            -w /etc/gshadow -p wa -k identity
            -w /etc/shadow -p wa -k identity
            -w /etc/security/opasswd -p wa -k identity
            
            # rule 4.1.7 Ensure events that modify the systems Mandatory Access Controls
            -w /etc/selinux/ -p wa -k MAC-policy
            -w /usr/share/selinux/ -p wa -k MAC-policy
            
            # rule 4.1.13 Ensure successful file system mounts are collected
            -a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
            -a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
            
            # rule 4.1.17 Ensure kernel module loading and unloading is collected
            -w /sbin/insmod -p x -k modules
            -w /sbin/rmmod -p x -k modules
            -w /sbin/modprobe -p x -k modules
            -a always,exit -F arch=b64 -S init_module -S delete_module -k modules
            
            # rule 4.1.11 Ensure unsuccessful unauthorized file access attempts are collected
            -a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
            -a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
            -a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
            -a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
            
            ##### THIS LINE MUST BE THE LAST #####
            # rule 4.1.18 Ensure the audit configuration is immutable
            -e 2
          EOS
          add_file('/etc/audit/auditd.conf', "root:root", "600", <<~EOS)
            #
            # This file controls the configuration of the audit daemon
            #
            
            # defaults
            #local_events = yes
            #write_logs = yes
            log_file = /var/log/audit/audit.log
            log_group = root
            log_format = RAW
            #flush = INCREMENTAL_ASYNC
            freq = 50
            max_log_file = 8
            num_logs = 5
            priority_boost = 4
            disp_qos = lossy
            dispatcher = /sbin/audispd
            name_format = NONE
            ##name = mydomain
            # max_log_file_action = ROTATE
            space_left = 75
            # space_left_action = SYSLOG
            #verify_email = yes
            action_mail_acct = root
            admin_space_left = 50
            # admin_space_left_action = SUSPEND
            disk_full_action = SUSPEND
            disk_error_action = SUSPEND
            use_libwrap = yes
            ##tcp_listen_port = 60
            tcp_listen_queue = 5
            tcp_max_per_addr = 1
            ##tcp_client_ports = 1024-65535
            tcp_client_max_idle = 0
            enable_krb5 = no
            krb5_principal = auditd
            ##krb5_key_file = /etc/audit/audit.key
            #distribute_network = no
            
            # rule 4.1.1.2 Ensure system is disabled when audit logs are full
            space_left_action = email
            admin_space_left_action = halt
            
            # rule 4.1.1.3 Ensure audit logs are not automatically deleted
            max_log_file_action = keep_logs
            
          EOS
        end
      end
    end
  end
end
