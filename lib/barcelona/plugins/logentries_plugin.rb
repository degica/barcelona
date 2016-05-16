module Barcelona
  module Plugins
    class LogentriesPlugin < Base
      LOCAL_LOGGER_PORT = 514 # TCP port for local rsyslog

      def on_container_instance_user_data(_instance, user_data)
        user_data.packages << "rsyslog-gnutls"
        user_data.add_file("/etc/ssl/certs/logentries.all.crt", "root:root", "644", <<END_OF_CERTIFICATE)
-----BEGIN CERTIFICATE-----
MIIE3jCCA8agAwIBAgICGbowDQYJKoZIhvcNAQELBQAwZjELMAkGA1UEBhMCVVMx
FjAUBgNVBAoTDUdlb1RydXN0IEluYy4xHTAbBgNVBAsTFERvbWFpbiBWYWxpZGF0
ZWQgU1NMMSAwHgYDVQQDExdHZW9UcnVzdCBEViBTU0wgQ0EgLSBHNDAeFw0xNDEw
MjkxMjI5MzJaFw0xNjA5MTQwODE3MzlaMIGWMRMwEQYDVQQLEwpHVDAzOTM4Njcw
MTEwLwYDVQQLEyhTZWUgd3d3Lmdlb3RydXN0LmNvbS9yZXNvdXJjZXMvY3BzIChj
KTEyMS8wLQYDVQQLEyZEb21haW4gQ29udHJvbCBWYWxpZGF0ZWQgLSBRdWlja1NT
TChSKTEbMBkGA1UEAxMSYXBpLmxvZ2VudHJpZXMuY29tMIIBIjANBgkqhkiG9w0B
AQEFAAOCAQ8AMIIBCgKCAQEAyvDKhaiboZS5GHaZ7HBsidUBJoBu1YqMgUxvFohv
xppf5QqjjDP4knjKyC3K8t7cMTFem1CXHA03AW0nImy2cbDcWhr7MpTr5J90e3Ld
neWfBiFNStzjaE9jhdWDvu0ctVact1TIQgYfSAlRMEKW+OuaUwq3dEJNRJNzdrzE
aefQN7c4e2IgTuFvU9p7Qzifiq9Qu1VoSSDK3lxZiQuChWtd4sGYhqqjbkkMRvQ/
pRdiJ0gcFtGaqZLaj3Op+poz40iOiubWB4U8iOHiSjoGdRVi0LJKUeiSRw9lRO+1
qbj4g9ASZU+g7XugZn5GQvrR8E6ha5nZHEdDTI8JiEHXLwIDAQABo4IBYzCCAV8w
HwYDVR0jBBgwFoAUC1Dsd+8qm//sA6EK/63G5CoYxz4wVwYIKwYBBQUHAQEESzBJ
MB8GCCsGAQUFBzABhhNodHRwOi8vZ3Uuc3ltY2QuY29tMCYGCCsGAQUFBzAChhpo
dHRwOi8vZ3Uuc3ltY2IuY29tL2d1LmNydDAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0l
BBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMB0GA1UdEQQWMBSCEmFwaS5sb2dlbnRy
aWVzLmNvbTArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8vZ3Uuc3ltY2IuY29tL2d1
LmNybDAMBgNVHRMBAf8EAjAAMFoGA1UdIARTMFEwTwYKYIZIAYb4RQEHNjBBMD8G
CCsGAQUFBwIBFjNodHRwczovL3d3dy5nZW90cnVzdC5jb20vcmVzb3VyY2VzL3Jl
cG9zaXRvcnkvbGVnYWwwDQYJKoZIhvcNAQELBQADggEBAGL2wkx4Gk99EAcW0ClG
sCVFUbZ/DW2So0c5MjKkfFIGdH4a++x9eTNi28GoeF6YF2S8tOKS4fHHHxby4Fvn
ToUp4yR3Z3zAwNFULC1Gc+1kaV0/6k99LuiKNlIU7CHocSjQs7zvmc85l152lrAL
pzodvnfOn8rjUZvGOi2hb8VC7ZUSQCD9NJNNexF6G4dYc2TBjCD5xrhYXNcYCDXu
TGtvFnmBzFIO06IjqPWUFnerZxkktHf63PCB+xTxRWtDc84K91jmc+u7k/yY5wdf
aigW0/FPgSXR+as3fD1SSLuIgHynDdsUYLtCdbqiIRpZc/cmXzJI0bzhzpgGDPcn
81I=
-----END CERTIFICATE-----

-----BEGIN CERTIFICATE-----
MIIERDCCAyygAwIBAgIDAjp4MA0GCSqGSIb3DQEBCwUAMEIxCzAJBgNVBAYTAlVT
MRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i
YWwgQ0EwHhcNMTQwODI5MjIyNDU4WhcNMjIwNTIwMjIyNDU4WjBmMQswCQYDVQQG
EwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEdMBsGA1UECxMURG9tYWluIFZh
bGlkYXRlZCBTU0wxIDAeBgNVBAMTF0dlb1RydXN0IERWIFNTTCBDQSAtIEc0MIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA30GUetr35DFDtuoBG1zOY+r6
baPZau4tmnX51ZxbvTTf2BzJbdgEiNputbe18DCuQNZd+sRTwdQinQROEaaV1UV8
QQVY4Ezd+e5VvV9G3K0TCJ0s5PeC5gcrng6MNKHOxKHggXCGAAY/Lep8myiuGyiL
OQnT5/BFpLG6EWeQVXuP3u04XKHh44PEw3KRT5juHMKAqmSlPoNiHMzgnvhawBMS
faKni6PnnyrXm8rL7ZcBnCiEUQRQQby0/HjpG88U6h8P/C4BMo22NcsKGDvsWj48
G9OZQx4v973zWxK5B17tPtGph8x3cifU2XWiY0uTNr3lXNe/X3kNszKnC7JjIwID
AQABo4IBHTCCARkwHwYDVR0jBBgwFoAUwHqYaI2J+6sFZAwRfap9ZbjKzE4wHQYD
VR0OBBYEFAtQ7HfvKpv/7AOhCv+txuQqGMc+MBIGA1UdEwEB/wQIMAYBAf8CAQAw
DgYDVR0PAQH/BAQDAgEGMDUGA1UdHwQuMCwwKqAooCaGJGh0dHA6Ly9nLnN5bWNi
LmNvbS9jcmxzL2d0Z2xvYmFsLmNybDAuBggrBgEFBQcBAQQiMCAwHgYIKwYBBQUH
MAGGEmh0dHA6Ly9nLnN5bWNkLmNvbTBMBgNVHSAERTBDMEEGCmCGSAGG+EUBBzYw
MzAxBggrBgEFBQcCARYlaHR0cDovL3d3dy5nZW90cnVzdC5jb20vcmVzb3VyY2Vz
L2NwczANBgkqhkiG9w0BAQsFAAOCAQEAMyTVkKopDDW5L8PHQpPAxhBLAwh2hBCi
4OdTEifyCtp/Otz9XHlajxd0Q1Ox1dFdWbmmhGTK8ToKWZYQv6mBV4tch9x/4+S7
BXqgMgkTThCBKB+cA2K89AG1KYNGB7nnuF3I6dHdrTv4NNvB0ZWpkRjtPCw3EU3M
/lM+UEP5w1ZBrFObbAWymuLgWVcwMrYmThMlzfpIcA91VWAR9TvVXlo8i1sPD2JC
SGGFixD0wYi/f1+KwtfNK5RcHzRKCK/rromoSHVVlR27wJoBufQDIj7U5lIwDWe5
wJH9LUwwjr2MpQSRu6Srfw/Yb/BmAMmjXPWwj4PmnFrmtrnFvL7kAg==
-----END CERTIFICATE-----
END_OF_CERTIFICATE

        user_data.add_file("/etc/rsyslog.d/barcelona-logger.conf", "root:root", "644", <<EOS)
$ModLoad imtcp
$InputTCPServerRun #{LOCAL_LOGGER_PORT}

$DefaultNetstreamDriverCAFile /etc/ssl/certs/logentries.all.crt
$ActionSendStreamDriver gtls
$ActionSendStreamDriverMode 1
$ActionSendStreamDriverAuthMode x509/name
$ActionSendStreamDriverPermittedPeer *.logentries.com

$ActionResumeInterval 10
$ActionQueueSize 100000
$ActionQueueDiscardMark 97500
$ActionQueueHighWaterMark 80000
$ActionQueueType LinkedList
$ActionQueueFileName logentriesqueue
$ActionQueueCheckpointInterval 100
$ActionQueueMaxDiskSpace 2g
$ActionResumeRetryCount -1
$ActionQueueTimeoutEnqueue 2
$ActionQueueDiscardSeverity 0

$template LogentriesTemplate,"#{token} %syslogtag% hostname=%hostname% %msg:1:1024%\\n"
*.* @@api.logentries.com:20000;LogentriesTemplate
EOS
        user_data.run_commands += [
          "service rsyslog restart"
        ]

        user_data
      end

      def on_heritage_task_definition(_heritage, task_definition)
        task_definition.merge(
          log_configuration: {
            log_driver: "syslog",
            options: {
              "syslog-address" => "tcp://127.0.0.1:#{LOCAL_LOGGER_PORT}",
              "tag" => task_definition[:name]
            }
          }
        )
      end

      private

      def token
        model.plugin_attributes[:token]
      end
    end
  end
end
