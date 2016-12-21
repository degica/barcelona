# Docker container for OSSEC

This Docker container source files can be found in our [ossec-wazuh Github repository](https://github.com/wazuh/ossec-wazuh). It includes both an OSSEC manager and an Elasticsearch single-node cluster, with Logstash and Kibana. You can find more information on how these components work together in our documentation.

## Documentation

* [Full documentation](http://documentation.wazuh.com)
* [OSSEC integration with ELK Stack](http://documentation.wazuh.com/en/latest/ossec_elk.html)
* [Docker container documentation](http://documentation.wazuh.com/en/latest/ossec_docker.html#ossec-elk-container)
* [Docker Hub](https://hub.docker.com/r/wazuh/docker-ossec-elk/)

## Credits and thank you

This Docker container is based on “xetus-oss” dockerfiles, which can be found at his [Github repository](https://github.com/xetus-oss/docker-ossec-server). We created our own fork, which we test and maintain. Thank you Terence Kent for your contribution to the community.

## References

* [Wazuh website](http://wazuh.com)
* [OSSEC project website](http://ossec.github.io)

## OSSEC Wazuh v1.1.1

Dear Wazuh community,

We have released OSSEC Wazuh v1.1.1, in this new release we fixed some issues regarding to logcollector, maild and remoted processes, also we are including last version of Wazuh Ruleset.
Some of the more important changes in this release are mentioned in the change log below.

### Added

- agent_control: maximum number of agents can now be extracted using option "-m".
- maild: timeout limitation, preventing it from hang in some cases.
- Updated decoders, ruleset and rootchecks from Wazuh Ruleset v1.0.8.
- Updated changes from ossec-hids repository.

### Changed

- Avoid authd to rename agent if overplaced.
- Changed some log messages.
- Reordered directories for agent backups.
- Don't exit when client.keys is empty by default.
- Improved client.keys reloading capabilities.

### Fixed

- Fixed JSON output at rootcheck_control.
- Fixed agent compilation on OS X.
- Fixed memory issue on removing timestamps.
- Fixed segmentation fault at reported.
- Fixed segmentation fault at logcollector.

### Removed

- Removed old rootcheck options.


## OSSEC Wazuh v1.1

We have released OSSEC Wazuh v1.1, in this new release we have improved the Agents management, we added mechanisms to prevent agent IP duplication, re-usage of old ID's, backup for agent information before deleting, force adding or alerting when duplicate IP conflicts.

This release will also include:

* Expanded RESTful API integration facilitating massive deployments using Wazuh Powershell or Python scripts
* Added improvements and fixes from others OSSEC forks
* Agents date created file
* Upgraded Ruleset v1.07


## Wazuh RESTful API v1.2 

This new release has been an effort to have a much more solid API. We would like to highlight especially the following new capabilities:

* Run the API as service.
* API Versioning by URL or HTTP header.
* On adding a new agent, the IP will be automatically detected.
* IP detection works behind a proxy server.


