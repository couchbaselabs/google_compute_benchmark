#!/bin/bash

#Increase ulimit on client machines
# TODO: move into client template.

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/gcloud_inc.sh

CLIENT="${NODE_CLIENT_PREFIX}"

for i in $(seq 9 32); do
    echo "* Increaing 'nofile' ulimit on client $i to 10240"
    gcloud_ssh ${CLIENT}-${i} "sudo bash -c 'echo -e \"@adm\thard\tnofile\t10240\" >> /etc/security/limits.conf'"
done
