#!/bin/bash

# Example script to automate cluster initialisation, add hosts and create buckets
# For illustration purposes only - paths, arguments and return values should be checked for errors

#
# Make sure couchbase-cli is in the path (Linux / Mac)
#

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source ${DIR}/settings

if [ `uname` == "Darwin" ]
then
export PATH=$PATH:/Applications/Couchbase\ Server.app/Contents/Resources/couchbase-core/bin/
else
    export PATH=$PATH:/opt/couchbase/bin/
fi

# Parameters for bucket one (couchbase-type)
BUCKET_NAME=$3
BUCKET_TYPE=couchbase  # memcached
BUCKET_QUOTA=$4
BUCKET_REPLICA=1
PORT=8091
USER=Administrator
PASS=password
CLUSTER_MEM=$3
CBPATH=/opt/couchbase/var/lib/couchbase/data

HOST1=$2

function createCluster {
#
# (Optional) set the path to be used to store both the data and indexes.
#
couchbase-cli node-init -c $HOST1 --node-init-data-path=$CBPATH --node-init-index-path=$CBPATH -u $USER -p $PASS

#
# Initialise the cluster with a single node, using the credentials specified above
#
couchbase-cli cluster-init -c $HOST1 \
        -u $USER \
        -p $PASS \
       --cluster-init-port=$PORT \
       --cluster-init-ramsize=$CLUSTER_MEM

#       --cluster-init-username=$USER \ # 2.x
#       --cluster-init-password=$PASS \ # 2.x

#
# Add all remaining nodes to the cluster
# This command can be copied (or used in a loop) for multiple hosts
# Start with the 4th param because cluster has been initialised with the first node

for N in $(seq 2 $NUM_SERVERS)
do
NODE=${NODE_PREFIX}-${N}.c.${PROJECT}.internal

#get external IP so we can set the datapath
NODEIP=$(gcloud compute instances describe --zone ${ZONE} ${NODE_PREFIX}-${N} | grep natIP | cut -d':' -f2)

echo Adding $NODE to the cluster
couchbase-cli node-init -c $NODEIP --node-init-data-path=$CBPATH --node-init-index-path=$CBPATH -u $USER -p $PASS
couchbase-cli server-add -c ${HOST1}:${PORT} \
      --user=${USER} \
      --password=${PASS} \
      --server-add=${NODE}:${PORT} \
      --server-add-username=${USER} \
      --server-add-password=${PASS}
done
#
# A rebalance is necessary to ensure all nodes added above are fully introduced to the
# cluster. This is best performed before adding buckets
#
couchbase-cli rebalance -c ${HOST1}:${PORT} --user=${USER} --password=${PASS}
}

function createBucket {

#
# Create a couchbase-type bucket using the credentials supplied above
#
couchbase-cli bucket-create -c ${HOST1}:${PORT} \
                --user=${USER} \
                --password=${PASS} \
                --bucket=${BUCKET_NAME} \
                --bucket-ramsize=${BUCKET_QUOTA} \
                --bucket-replica=${BUCKET_REPLICA} \
                --bucket-type=${BUCKET_TYPE}

}


case "$1" in
        create-cluster)
            if [ "$#" -lt 3 ]
            then
              echo "Usage $0 create-cluster <node1-external-ip> <cluster-ram-MB>"
              exit
            fi
            echo "Creating cluster with ${CLUSTER_MEM}MB of RAM and $NUM_SERVERS node(s)"
            createCluster
            ;;
        create-bucket)
            if [ "$#" -lt 4 ]
            then
              echo "Usage $0 create-bucket <node1-external-ip> <bucket-name> <bucket-size-MB>"
              exit
            fi
            echo "Creating bucket ${BUCKET_NAME} with size ${BUCKET_QUOTA}MB"
            createBucket
            ;;
        *)
            echo $"Usage: $0 {create-cluster <node1-external-ip> <cluster-ram-MB>|create-bucket <node1-external-ip> <bucket-name> <bucket-size-MB>}"
            exit 1

esac