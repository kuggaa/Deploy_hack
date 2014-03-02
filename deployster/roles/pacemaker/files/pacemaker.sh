#!/bin/sh
cibadmin -U -X '<cib validate-with="pacemaker-1.1"/>'
cibadmin --replace --scope resources --xml-file /tmp/resources.xml
cibadmin --replace --scope constraints --xml-file /tmp/constraints.xml
cibadmin -M -c -o configuration --xml-file /tmp/fencing_topology.xml
crm_attribute --attr-name stonith-enabled --attr-value true
crm_attribute --attr-name no-quorum-policy --attr-value stop
