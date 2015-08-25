#!/bin/bash

#
# Common constants / functions for working with GCE
#

PROJECT="cb-googbench-101"
ZONE="us-central1-f"

# Run a command on the specified host, using a gateway machine as there
# may not be an external IP.
gcloud_ssh() {
    host=$1
    shift
    gateway=${NODE_CLIENT_PREFIX}-1

    if [[ $host == $gateway ]]; then
        # Direct connection
        gcloud compute --project ${PROJECT} ssh --zone ${ZONE} ${host} --command "$*"
    else
        # Bounce via gateway
        gcloud compute --project ${PROJECT} ssh --zone ${ZONE} ${gateway} \
               --ssh-flag="-A" --ssh-flag="-o LogLevel=ERROR" \
               --command "ssh -o CheckHostIP=no -o StrictHostKeyChecking=no ${host} \"$*\""
    fi
}

