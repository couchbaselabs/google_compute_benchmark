#!/bin/bash

# Checks out latest pillowfight on first client, builds then copies to all other clients.

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/gcloud_inc.sh

CLIENT="cb-client"
NUM_CLIENTS=32

# Copy from one GCE instance to another. Source instance must be SSH'able
# from outside (i.e. where this script is run).
gcloud_scp() {
    src_host=$1
    src_file=$2
    dst_host=$3
    dst_file=$4

    gcloud compute --project ${PROJECT} ssh --zone ${ZONE} ${src_host} \
           --ssh-flag="-A" \
           --command "scp -o CheckHostIP=no -o StrictHostKeyChecking=no $src_file ${dst_host}:${dst_file}"

}

BRANCH=durability_tokens
for i in $(seq 1 ${NUM_CLIENTS}); do
    echo "===Client $i==="
    if [[ $i == "1" ]]; then
        # 1 is special - checkout and build.
        gcloud_ssh ${CLIENT}-${i} "sudo apt-get install -y cmake git libevent-dev"
        gcloud_ssh ${CLIENT}-${i} "(cd libcouchbase && git fetch && git reset --hard origin/${BRANCH}) || git clone https://github.com/daverigby/libcouchbase.git --branch ${BRANCH}"
        gcloud_ssh ${CLIENT}-${i} "cd libcouchbase && mkdir -p build && cd build && ../cmake/configure && make"
    fi

    # Copy binary to same location on all machines.
    gcloud_scp ${CLIENT}-1 libcouchbase/build/bin/cbc-pillowfight ${CLIENT}-$i .
done
wait
