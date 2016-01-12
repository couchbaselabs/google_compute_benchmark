#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/settings

function deleteSnapshots {
    gcloud compute snapshots delete $CLIENT_SNAPSHOT
    gcloud compute snapshots delete $SERVER_SNAPSHOT
}

read -p "Delete everything? Are you sure (y/n)? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

${DIR}/control_instances.sh delete-forced
deleteSnapshots
