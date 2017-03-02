#!/usr/bin/env python

# Wazuh installer for ELK integration index and dashboards
# Copyright (C) 2016 Wazuh, Inc. <info@wazuh.com>.
# May 23, 2016.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

import sys
import datetime
import json
import urllib2
import os
import requests

ES_URL = 'https://{0}'.format(os.environ['ELASTICSEARCH_URL'])
KIBANA_VERSION = "4.1.2-es-2.0"

# Remote github files
MAPPING_FILE_URL = "https://raw.githubusercontent.com/wazuh/ossec-wazuh/stable/extensions/elasticsearch/elastic-ossec-template.json"
OBJECTS_FILE_URL = "https://raw.githubusercontent.com/wazuh/ossec-wazuh/stable/extensions/kibana/kibana-ossecwazuh-dashboards.json"

# Import mapping to elasticsearch
print("+ Importing mapping template...")
try:
    r = requests.put('{0}/_template/ossec/'.format(ES_URL), data = urllib2.urlopen(MAPPING_FILE_URL).read())
except:
    print("[ERROR] Could not connect with Elasticsearch at {0}".format(ES_URL))
    sys.exit(1)
if (r.text != '{"acknowledged":true}'):
    print("[ERROR] Mapping template could not be imported.")
    sys.exit(1)

# Create ossec-* index
print("+ Creating ossec-* index...")
try:
    r = requests.post('{0}/.kibana-4/index-pattern/ossec-*?op_type=create'.format(ES_URL), data = '{title: "ossec-*", timeFieldName: "@timestamp"}')
except:
    print("[ERROR] Could not connect with Elasticsearch at {0}".format(ES_URL))
    sys.exit(1)
if (r.status_code != 201):
    print("[ERROR] Could not create ossec-* index. It already exists?")
#    sys.exit(1)

# Create ossec-* index pattern
print("+ Creating ossec-* index pattern...")
try:
    r = requests.post('{0}/.kibana-4/index-pattern/ossec-*'.format(ES_URL), data = '{"title":"ossec-*","timeFieldName":"@timestamp"}')
except:
    print("[ERROR] Could not connect with Elasticsearch at {0}".format(ES_URL))
    sys.exit(1)
if (r.status_code != 200):
    print("[ERROR] Could not create ossec-* index pattern. Check if the pattern exists.")
#    sys.exit(1)

# Set ossec-* index by default
print("+ Setting ossec-* index as default index for Kibana...")
try:
    r = requests.post('{0}/.kibana-4/config/{1}/_update'.format(ES_URL, KIBANA_VERSION), data= '{"doc":{"defaultIndex":"ossec-*"}}')
except:
    print("[ERROR] Could not connect with Elasticsearch at {0}".format(ES_URL))
    sys.exit(1)
if (r.status_code != 200):
    print("[ERROR] Could not set ossec-* as default index for Kibana. Is the Kibana version correct?")
    sys.exit(1)

# Set last 24h as default search time
print("+ Setting last 24h as default search time...")
try:
    r = requests.post('{0}/.kibana-4/config/{1}/_update'.format(ES_URL, KIBANA_VERSION), data= '{"doc":{"defaultIndex":"ossec-*","timepicker:timeDefaults":"{\\n \\"from\\": \\"now-24h\\",\\n \\"to\\": \\"now\\",\\n \\"mode\\": \\"quick\\"\\n}"}}')
except:
    print("[ERROR] Could not connect with Elasticsearch at {0}".format(ES_URL))
    sys.exit(1)
if (r.status_code != 200):
    print("[ERROR] Could not set last 24h as default search time. Is the Kibana version correct?")
    sys.exit(1)

# Import dashboards, searches and visualizations
print("+ Importing Kibana objects (dashboards, searches and visualizations). This can take some time...")
jsonObjects = {}
#Download file and convert to JSON
try:
    objects = urllib2.urlopen(OBJECTS_FILE_URL).read()
    jsonObjects = json.loads(objects)
except:
    print("[ERROR] Could not load the objects JSON data")
    sys.exit(1)
importSuccess = True
#Iterate over the JSON
for kobject in jsonObjects:
    try:
        #Import object
        r = requests.post('{0}/.kibana-4/{1}/{2}?op_type=create'.format(ES_URL, kobject["_type"], kobject["_id"]), data = json.dumps(kobject["_source"]))
        if (r.status_code != 201):
            importSuccess = False
            print("[ERROR] Error importing {0} {1}. It already exists?".format(kobject["_type"], kobject["_id"]))
    except:
        importSuccess = False
        print("[ERROR] Could not connect with Elasticsearch at {0}".format(ES_URL))

#Final installer message
if (importSuccess):
    print("[SUCCESS] Kibana for Wazuh is ready for using")
    sys.exit(0)
else:
    print("[ERROR] Kibana for Wazuh is installed, but all the objects were not imported.")
    sys.exit(1)
